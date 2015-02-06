# Parallel HTK
If you are using the good ol' HTK software to train your speech / handwritten
recognition HMMs, you'll probably need to run your experiments in parallel.

This set of scripts may be helpful to run the embedded Baum-Welch (EM) algorithm
to train your models, using multiple CPUs in your local machine, or even a
SGE cluster.

Please, be aware that I created this scripts mainly for my own research. So
they may not fit 100% of your purposes. Feel free to modify them, but please,
respect the Apache license.

## Train embedded HMMs

Train HMMs using feature files listed in `train.scp`, using the master label
file (MLF) `train.mlf`. The list of HMMs is specified in file `hmm_symbols.lst`
and the experiments are run in exp_dir.

```bash
parallel-htk-train htk_config train.scp train.mlf hmm_symbols.lst exp_dir
```

Parallel training using 4 processes in the local machine. This will split the
original `train.scp` into 4 different files, and run 4 HERest processes in
parallel.

```bash
parallel-htk-train --num_tasks 4 htk_config train.scp train.mlf hmm_symbols.lst exp_dir
```

You can also schedule multiple jobs in a SGE cluster, one for each training
step.

```bash
parallel-htk-train --sge true htk_config train.scp train.mlf hmm_symbols.lst exp_dir
```

Usually, if you are training with a big corpus, you want to split each EM
iteration into multiple SGE tasks. In this case, each EM iteration is splitted
into 200 tasks.

```bash
parallel-htk-train --sge true --num_tasks 200 htk_config train.scp train.mlf hmm_symbols.lst exp_dir
```

If your corpus is not that big, but you still want to use SGE, notice that it
might be wiser to schedule a single job running different processes. In the
following examples, 4 tasks are run in parallel in a single SGE job.

```bash
qsub -cwd -b y -pe mp 4 parallel-htk-train --num_tasks 4 htk_config train.scp train.mlf hmm_symbols.lst exp_dir
```

Option `-b y` is mandatory, otherwise SGE will fail to locate to some scripts
needed by `parallel-htk-train`.

### Usage

```
Usage: parallel-htk-train [options] <htk_config> <train_scp> <train_mlf> <symb_list> <out_dir>

Arguments:
  htk_config : HTK configuration file. Important: It must define the
               "NUMCEPS" variable, since it will be used to create the
               initial HMMs.
  train_scp  : File(s) containing the list of feature files used for training.
               If multiple files are given, multiple processes will be used
               for parallel training.
  train_mlf  : Training labels file, in HTK Master Label Format (MLF).
  symb_list  : File containing the list of the HMM symbols to train.
  out_dir    : Working directory where the training will write results.

Options:
  --em_iters      : type = integer, default = 4
                    Number of EM iterations, for each number of mixtures.
  --mix_iters     : type = integer, default = 7
                    Number of times the mixtures are incremented.
  --mix_factor    : type = float, default = 2.0
                    Increment the number of mixtures by this factor.
  --num_states    : type = interger, default = 6
                    Number of states in each Hidden Markov Model.
  --num_tasks     : type = integer, default = 1
                    Perform parallel training splitting the input SCP in this
                    number of tasks.
  --overwrite     : type = boolean, default = true
                    If true, overwrites any previous existing result. You may
                    want to set this to false if you want to continue from a
                    previous experiment (i.e. a failed experiment, increase the
                    number of gaussian mixtures, EM iterations, etc).
  --qsub          : type = boolean, default = false
                    If true, parallelize training using SGE qsub.
  --qsub_em_mem   : type = string, default = "256M"
                    Requested maximum memory by qsub for the EM tasks.
  --qsub_em_rt    : type = string, default = "10:00:00"
                    Requested maximum running time by qsub for the EM tasks.
  --qsub_hhed_mem : type = string, default = "100M"
                    Requested maximum memory by qsub for the HHEd step, where
                    the number of mixtures are increased.
  --qsub_hhed_rt  : type = string, default = "00:10:00"
                    Requested maximum running time by qsub for the HHEd step,
                    where the number of mixtures are increased.
  --qsub_init_mem : type = string, default = "120M"
                    Requested maximum memory by qsub for the HMM initialization
                    step.
  --qsub_init_rt  : type = string, default = "01:00:00"
                    Requested maximum running time by qsub for the HMM
                    initialization step.
  --qsub_opts     : type = string, default = ""
                    Other qsub options. Qsub may be called with additional
                    options added automatically, like "-cwd", "-t",
                    "-l h_vmem", "-l h_rt", etc.
```
