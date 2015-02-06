#!/bin/bash

# Copyright 2015  Joan Puigcerver

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
# WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
# MERCHANTABLITY OR NON-INFRINGEMENT.
# See the Apache 2 License for the specific language governing permissions and
# limitations under the License.

## Script directory
SDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );

hold_jid="";
overwrite=true;
qsub_opts="-l h_rt=10:00:00,h_vmem=256M";
help_message="
Usage: ${0##*/} [options] <scp> ... <mlf> <symbs> <config> <wdir> <iter>

Description:
  Perform an embedded-EM iteration using HTK's HERest.
  This script assumes that some previous model is available in
  \"<work_dir>/it_<iteration - 1>/hmms\".

  The script can launch several SGE tasks by giving multiple scp files.

Arguments:
  scp    : File(s) containing the list of feature files used for training.
           If multiple files are given, the SGE job will be divided in
           multiple tasks for parallel training.
  mlf    : Training labels file, in HTK Master Label Format (MLF).
  symbs  : File containing the list of the HMM symbols to train.
  config : HTK configuration file.
  wdir   : Working directory containing all HERest iterations.
  iter   : Iteration number to execute.

Options:
  --hold_jid  : type = string,  default = \"${hold_jid}\"
                Wait for the completion of this SGE job, before start.
  --overwrite : type = boolean, default = ${overwrite}
                If true, overwrites any previous existing model of the current
                iteration, even if it was successfully completed.
  --qsub_opts : type = string, default = \"${qsub_opts}\"
                Additional options for qsub. \"-cwd\", \"-t\" and \"-hold_jid\"
                options are set automatically.
"

. "${SDIR}/parse_options.sh" || exit 1;
[ $# -lt 6 ] && echo "${help_message}" >&2 && exit 1;

train_lst=("${@:1:$[$#-5]}");
train_mlf="${@:(-5):1}";
symb_lst="${@:(-4):1}";
config="${@:(-3):1}";
wdir="${@:(-2):1}";
k="${@:(-1):1}";
inpf="${wdir}/it_$[k-1]/hmms";
outf="${wdir}/it_${k}/hmms";

## Check arguments
[ "${k}" -lt 1 ] && \
    echo "ERROR (${0##*/}:${LINENO}): Invalid iteration k = ${k}!" >&2 && \
    exit 1;
for file in "${train_lst[@]}" "${train_mlf}" "${symb_lst}" "${config}"; do
    [ ! -s "${file}" ] && \
        echo "ERROR (${0##*/}:${LINENO}): File \"${file}\" not found!" >&2 && \
	exit 1;
done;

## Check if we don't need to re-do the work again
[ "${overwrite}" = "false" ] && [ -s "${outf}" ] && \
    echo "WARNING (${0##*/}:${LINENO}): File \"${outf}\" was not overwritten!" >&2 && \
    exit 0;

## Prepare qsub arguments if we have to wait for any job
[ -n "${hold_jid}" ] && hold_jid="-hold_jid ${hold_jid}";

mkdir -p "${wdir}/it_${k}"
if [ "${#train_lst[@]}" -gt 1 ]; then
    ## Launch mapper tasks ...
    mapper_jobid=$(for n in $(seq 1 "${#train_lst[@]}"); do
   cat <<EOF
[ \${SGE_TASK_ID} -eq ${n} ] && {
[ ! -s "${inpf}" ] && \
    echo "ERROR (${0##*/}:${LINENO}): File \"${inpf}\" not found!" >&2 && exit 1;
[ "${overwrite}" = "false" ] && [ -s "${wdir}/it_${k}/HER${n}.acc" ] && \
    echo "WARNING (${0##*/}:${LINENO}): File \"${wdir}/it_${k}/HER${n}.acc\" was not overwritten!" >&2 && \
    exit 0;
date >&2;
HERest -A -T 1 -C "${config}" -v 0.01 -m 3 -S "${train_lst[n-1]}" \
    -I "${train_mlf}" -H "${inpf}" -M "${wdir}/it_${k}" -p "${n}" \
    "${symb_lst}" &> "${wdir}/it_${k}/HERest.${n}.log" || { \
echo "ERROR (${0##*/}:${LINENO}): HERest failed, see ${wdir}/it_${k}/HERest.${n}.log" >&2; \
date >&2; exit 1; }
date >&2;
}
EOF
   done | qsub -cwd ${qsub_opts} ${hold_jid} -t "1-${#train_lst[@]}" | \
       awk '/Your job-array/{ gsub(/\..*/, "", $3); print $3}' || { \
       echo "ERROR (${0##*/}:${LINENO}): qsub job submission failed!" >&2; \
       exit 1; });

   ## Launch reducer job. This job will wait for the mapper tasks to complete.
   ## At the end, prints the job ID of the reducer
   ( cat <<EOF
date >&2;
HERest -A -T 1 -C "${config}" -v 0.01 -m 3 -H "${inpf}" -M "${wdir}/it_${k}" \
    -p 0 "${symb_lst}" "${wdir}/it_${k}/"*.acc \
    &> "${wdir}/it_${k}/HERest.0.log" || { \
echo "ERROR (${0##*/}:${LINENO}): HERest failed, see ${wdir}/it_${k}/HERest.0.log" >&2; \
date >&2; exit 1; }
date >&2;
EOF
   ) | qsub -cwd ${qsub_opts} -hold_jid "${mapper_jobid}" | \
       awk '/Your job/{print $3}' || { \
       echo "ERROR (${0##*/}:${LINENO}): qsub job submission failed!" >&2; \
       exit 1; }
else
    ( cat <<EOF
[ ! -s "${inpf}" ] && \
    echo "ERROR (${0##*/}:${LINENO}): File \"${inpf}\" not found!" >&2 && exit 1;
date >&2;
HERest -A -T 1 -C "${config}" -v 0.01 -m 3 -S "${train_lst[@]}" \
    -I "${train_mlf}" -H "${inpf}" -M "${wdir}/it_${k}" "${symb_lst}" \
    &> "${wdir}/it_${k}/HERest.0.log"  || { \
echo "ERROR (${0##*/}:${LINENO}): HERest failed, see ${wdir}/it_${k}/HERest.0.log" >&2; \
date >&2; exit 1; }
date >&2;
EOF
    ) | qsub -cwd ${qsub_opts} ${hold_jid} | \
        awk '/Your job/{ gsub(/\..*/, "", $3); print $3}' || { \
        echo "ERROR (${0##*/}:${LINENO}): qsub job submission failed!" >&2; \
        exit 1; }
fi;