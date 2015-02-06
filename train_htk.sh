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

em_iters=4;
mix_iters=7;
mix_factor=2.0;
num_states=6;
num_tasks=1;
overwrite=true;
qsub=false;
qsub_em_mem="256M";
qsub_em_rt="10:00:00";
qsub_hhed_mem="100M";
qsub_hhed_rt="00:10:00";
qsub_init_mem="120M";
qsub_init_rt="01:00:00";
qsub_opts="";
help_message="
Usage: ${0##*/} [options] <htk_config> <train_scp> <train_mlf> <symb_list> <out_dir>

Arguments:
  htk_config : HTK configuration file. Important: It must define the
               \"NUMCEPS\" variable, since it will be used to create the
               initial HMMs.
  train_scp  : File(s) containing the list of feature files used for training.
               If multiple files are given, multiple processes will be used
               for parallel training.
  train_mlf  : Training labels file, in HTK Master Label Format (MLF).
  symb_list  : File containing the list of the HMM symbols to train.
  out_dir    : Working directory where the training will write results.

Options:
  --em_iters      : type = integer, default = ${em_iters}
                    Number of EM iterations, for each number of mixtures.
  --mix_iters     : type = integer, default = ${mix_iters}
                    Number of times the mixtures are incremented.
  --mix_factor    : type = float, default = ${mix_factor}
                    Increment the number of mixtures by this factor.
  --num_states    : type = interger, default = ${num_states}
                    Number of states in each Hidden Markov Model.
  --num_tasks     : type = integer, default = ${num_tasks}
                    Perform parallel training splitting the input SCP in this
                    number of tasks.
  --overwrite     : type = boolean, default = ${overwrite}
                    If true, overwrites any previous existing result.
  --qsub          : type = boolean, default = ${use_sge}
                    If true, parallelize training using SGE qsub.
  --qsub_em_mem   : type = string, default = \"${qsub_em_mem}\"
                    Requested maximum memory by qsub for the EM tasks.
  --qsub_em_rt    : type = string, default = \"${qsub_em_rt}\"
                    Requested maximum running time by qsub for the EM tasks.
  --qsub_hhed_mem : type = string, default = \"${qsub_hhed_mem}\"
                    Requested maximum memory by qsub for the HHEd step, where
                    the number of mixtures are increased.
  --qsub_hhed_rt  : type = string, default = \"${qsub_hhed_rt}\"
                    Requested maximum running time by qsub for the HHEd step,
                    where the number of mixtures are increased.
  --qsub_init_mem : type = string, default = \"${qsub_init_mem}\"
                    Requested maximum memory by qsub for the HMM initialization
                    step.
  --qsub_init_rt  : type = string, default = \"${qsub_init_rt}\"
                    Requested maximum running time by qsub for the HMM
                    initialization step.
  --qsub_opts     : type = string, default = \"${qsub_opts}\"
                    Other qsub options. Qsub may be called with additional
                    options added automatically, like \"-cwd\", \"-t\",
                    \"-l h_vmem\", \"-l h_rt\", etc.
";

. "${SDIR}/parse_options.sh" || exit 1;
[ $# -ne 5 ] && echo "${help_message}" >&2 && exit 1;

config="$1";
train_lst="$2";
train_mlf="$3";
symb_lst="$4";
wdir="$5";
em_qsub_opts="${qsub_opts} -l h_vmem=${qsub_em_mem},h_rt=${qsub_em_rt}";
hhed_qsub_opts="${qsub_opts} -l h_vmem=${qsub_hhed_mem},h_rt=${qsub_hhed_rt}";
init_qsub_opts="${qsub_opts} -l h_vmem=${qsub_init_mem},h_rt=${qsub_init_rt}";

## Check input files
for file in "${config}" "${train_lst}" "${train_mlf}" "${symb_lst}"; do
    [ ! -s "${file}" ] && \
        echo "ERROR (${0##*/}:${LINENO}): File \"${file}\" not found!" >&2 && \
        exit 1;
done

feat_dim=$(awk 'toupper($1)=="NUMCEPS"{print $NF}' "${config}" | bc -s || { \
    echo "ERROR (${0##*/}:${LINENO}): Failed to read NUMCEPS variable" >&2; \
    exit 1; });

## Compute global means and variances with HCompV and initialize HMMs
echo "--- HMM Initialization ..."
[[ ! -s "${wdir}/gmm_1/it_0/hmms" || "${overwrite}" = true ]] && {
    mkdir -p "${wdir}/gmm_1/it_0"
    bash "${SDIR}/create_proto.sh" "${feat_dim}" "${num_states}" \
        > "${wdir}/proto" || { \
        echo "ERROR (${0##*/}:${LINENO}): HMM proto creation failed!" >&2; \
        exit 1; }
    if [ "${qsub}" = false ]; then
        HCompV -A -T 1 -C "${config}" -f 0.01 -m -S "${train_lst}" \
            -M "${wdir}" "${wdir}/proto" &> "${wdir}/HCompV.log" || { \
            echo "ERROR (${0##*/}:${LINENO}): HCompV failed!" >&2; \
            exit 1; }
        bash "${SDIR}/create_init_hmm.sh" "${wdir}/proto" \
            "${wdir}/vFloors" "${symb_lst}" > "${wdir}/gmm_1/it_0/hmms" || { \
            echo "ERROR (${0##*/}:${LINENO}): create_init_hmm.sh failed!" >&2; \
            exit 1; }
    else
        last_jid=$(echo "
date >&2;
HCompV -A -T 1 -C \"${config}\" -f 0.01 -m -S \"${train_lst}\" \
   -M \"${wdir}\" \"${wdir}/proto\" \
   &> \"${wdir}/HCompV.log\" || { \
   echo \"ERROR (${0##*/}:${LINENO}): HCompV failed!\" >&2; \
   exit 1; }
date >&2;
bash \"${SDIR}/create_init_hmm.sh\" \"${wdir}/proto\" \
    \"${wdir}/vFloors\" \"${symb_lst}\" \
    > \"${wdir}/gmm_1/it_0/hmms\" || { \
    echo \"ERROR (${0##*/}:${LINENO}): create_init_hmm.sh failed!\" >&2; \
    exit 1; }
date >&2;
" | qsub -cwd ${init_qsub_opts} | awk '/Your job/{print $3}' || { \
    echo "ERROR (${0##*/}:${LINENO}): qsub job submission failed!"; \
    exit 1; });
        echo "--- Submitted job: ${last_jid}";
    fi;
}

## Split training data
[ "${num_tasks}" -gt 1 ] && {
    total_lines=$(wc -l "${train_lst}" | cut -d\  -f1);
    split_lines=$(echo "(${total_lines} + ${num_tasks} - 1)/${num_tasks}" | bc);
    train_prefix="${wdir}/data/$(basename ${train_lst}).part";
    mkdir -p "${wdir}/data";
    split -d -a 4 -l "${split_lines}" "${train_lst}" "${train_prefix}";
    train_lst=( $(ls "${train_prefix}"* || exit 1) );
}

## HMM Training
g=1;
for i in $(seq 0 $[mix_iters-1]); do
    ## EM Iterations
    for k in $(seq 1 ${em_iters}); do
	printf -- "--- Training %d states, %d mixtures (it. %d) ...\n" \
	    "${num_states}" "${g}" "${k}";
	mkdir -p ${wdir}/gmm_${g}/it_${k};
        if [ "${qsub}" = false ]; then
            bash "${SDIR}/herest_local.sh" --overwrite "${overwrite}" \
                "${train_lst[@]}" "${train_mlf}" "${symb_lst}" \
                "${config}" "${wdir}/gmm_${g}" "${k}" || exit 1;
        else
            last_jid=$(bash "${SDIR}/herest_sge.sh" \
                --overwrite "${overwrite}" --hold_jid ${last_jid} \
                --qsub_opts "${em_qsub_opts}" "${train_lst[@]}" "${train_mlf}" \
                "${symb_lst}" "${config}" "${wdir}/gmm_${g}" "${k}" \
                || exit 1);
            echo "--- Submitted job: ${last_jid}";
        fi;
    done
    ## Increase number of mixtures of gaussians
    [ $i -lt $[mix_iters - 1] ] && {
	ng=$(python -c \
	    "from math import ceil; print int(ceil($g * $mix_factor))");
	mkdir -p "${wdir}/gmm_${ng}/it_0";
        [[ ! -s "${wdir}/gmm_${ng}/it_0/hmms" || "${overwrite}" = true ]] && {
	    echo "MU ${ng} {*.state[2-$[num_states+1]].mix}" \
	        > "${wdir}/gmm_${ng}/it_0/hhed_script";
            if [ "${qsub}" = false ]; then
	        HHEd -A -H "${wdir}/gmm_${g}/it_${em_iters}/hmms" \
	            -M "${wdir}/gmm_${ng}/it_0" \
                    "${wdir}/gmm_${ng}/it_0/hhed_script" "${symb_lst}" \
	            &> "${wdir}/gmm_${ng}/it_0/HHEd.log" || { \
                    echo "ERROR (${0##*/}:${LINENO}): HHEd failed for g=${g}, ng=${ng}" >&2; \
                    exit 1; }
            else
                [ -n "${last_jid}" ] && hold_jid="-hold_jid ${last_jid}";
                last_jid=$(echo "
date >&2;
HHEd -A -H \"${wdir}/gmm_${g}/it_${em_iters}/hmms\" \
    -M \"${wdir}/gmm_${ng}/it_0\" \
    \"${wdir}/gmm_${ng}/it_0/hhed_script\" \
    \"${symb_lst}\"  &> \"${wdir}/gmm_${ng}/it_0/HHEd.log\" || { \
    echo \"ERROR (${0##*/}:${LINENO}): HHEd failed for g=${g}, ng=${ng}\" >&2; \
    exit 1; }
date >&2;" | qsub -cwd ${hhed_qsub_opts} ${hold_jid} | \
    awk '/Your job/{print $3}' || { \
    echo "ERROR (${0##*/}:${LINENO}): qsub job submission failed!"; \
    exit 1; });
                echo "--- Submitted job: ${last_jid}";
            fi;
	    g=$ng;
        }
    }
done
