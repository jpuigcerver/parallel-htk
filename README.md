# Parallel HTK
If you are using the good ol' HTK software to train your speech / handwritten
recognition HMMs, you'll probably need to run your experiments in parallel.

This set of scripts may be helpful to run the embedded Baum-Welch (EM) algorithm
to train your models, using multiple CPUs in your local machine, or even a
SGE cluster.

There is also a script included to perform Viterbi decoding of multiple files
in parallel, using HTK's HVite.

Please, be aware that I created this scripts mainly for my own research. So
they may not fit 100% of your purposes. Feel free to modify them, but please,
respect the Apache license.

## Train embedded HMMs

Train HMMs using feature files listed in `train.lst`, using the master label
file (MLF) `train.mlf`. The list of HMMs is specified in file `hmm_symbols.lst`
and the experiments are run in `exp_dir`.

```bash
parallel-htk-train htk_config train.mlf hmm_symbols.lst exp_dir train.lst
```

Parallel training using 4 processes in the local machine. This will split the
original `train.lst` into 4 different files (assuming there are 1000 files
listed in `train.lst`), and run 4 HERest processes in parallel.

```bash
split -l 250 -d train.lst train.lst.part
parallel-htk-train htk_config train.mlf hmm_symbols.lst exp_dir train.lst.part*
```

You can also schedule multiple jobs in a SGE cluster, one for each training
step.

```bash
parallel-htk-train --qsub true htk_config train.mlf hmm_symbols.lst exp_dir train.lst
```

Usually, if you are training with a big corpus, you want to split each EM
iteration into multiple SGE tasks. In this case, each EM iteration is splitted
into 200 tasks.

```bash
split -l 5 -d train.lst train.lst.part
parallel-htk-train --qsub true htk_config train.mlf hmm_symbols.lst exp_dir train.lst.part*
```

If your corpus is not that big, but you still want to use SGE, notice that it
might be wiser to schedule a single job running different processes. In the
following examples, 4 tasks are run in parallel in a single SGE job.
In general, take into consideration the overhead introduced by the SGE
scheduler when running multiple jobs with SGE.

```bash
split -l 250 -d train.lst train.lst.part
qsub -cwd -b y -pe mp 4 parallel-htk-train htk_config train.mlf hmm_symbols.lst exp_dir train.lst.part*
```

Option `-b y` is mandatory, otherwise SGE will fail to locate to some scripts
needed by `parallel-htk-train`.

### Usage
```
Usage: parallel-htk-train [options] <htk_config> <train_mlf> <symb_list> <out_dir> <train_lst> ...

Arguments:
  htk_config   : HTK configuration file. Important: It must define the
                 "NUMCEPS" variable, since it will be used to create the
                 initial HMMs.
  train_mlf    : Training labels file, in HTK Master Label Format (MLF).
  symb_list    : File containing the list of the HMM symbols to train.
  out_dir      : Working directory where the training will write results.
  train_lst(s) : File(s) containing the list of feature files used for training.
                 If multiple files are given, multiple processes will be used
                 for parallel training.

Options:
  --em_iters      : type = integer, default = 4
                    Number of EM iterations, for each number of mixtures.
  --mix_iters     : type = integer, default = 7
                    Number of times the mixtures are incremented.
  --mix_factor    : type = float, default = 2.0
                    Increment the number of mixtures by this factor.
  --num_states    : type = interger, default = 6
                    Number of states in each Hidden Markov Model.
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

## Viterbi decoding

Once you have trained your HMMs, you probably want to perform some kind of
sequence recognition (speech, handwritten text, etc). HTK includes the HVite
program to perform a Viterbi decoding over a set of files.

Parallelize the decoding of multiple files is trivial, since multiple instances
of HVite can run in parallel. The `parallel-htk-decode` may be useful to
run decoding experiments in parallel.

This example decodes the feature files in `test.lst` using the HMMs defined
in `hmms` and the lexicon `lexicon.dic`. The list of HMMs is specified in
the file `hmm_symbols.lst` and the experiments are run in the directory
`recog`.

```bash
parallel-htk-decode htk_config hmms lexicon.dic hmm_symbols.lst recog test.lst
```

Once again, you can run the decoding in parallel spliting the original file
list. Assuming 1000 files are included in test.lst, this launches 4 processes
in parallel running HVite in your machine.

```bash
split -l 250 -d test.lst test.lst.part
parallel-htk-decode htk_config hmms lexicon.dic hmm_symbols.lst recog test.lst.part*
```

You can also schedule jobs in SGE. For instance, this will schedule 200 jobs.

```bash
split -l 5 -d train.lst train.lst.part
parallel-htk-decode --qsub true htk_config hmms lexicon.dic hmm_symbols.lst recog test.lst.part*
```

Remember, as we pointer before, to take into consideration the overhead
introduced by the SGE scheduler. If you want to launch a single SGE job running
multiple processes in parallel, follow this example:

```bash
split -l 250 -d test.lst test.lst.part
qsub -cwd -b y -pe mp 4 parallel-htk-decode htk_config hmms lexicon.dic hmm_symbols.lst recog test.lst.part*
```

### Usage
```
Usage: parallel-htk-decode [options] <htk_config> <hmms> <lexicon> <hmm_symbs> <out_dir> <test_lst> ...

Arguments:
  htk_config  : HTK configuration file.
  hmms        : File containing the HMMs definitions.
  lexicon     : HTK lexicon file containing the mapping from words to HMM
                symbols.
  hmm_symbs   : File containing the list of the HMM symbols to train.
  out_dir     : Output directory containing the decoding hypothesis,
                lattices, etc.
  test_lst(s) : Input file(s) containing the list of feature files to decode.
                If multiple files are given, each of them will be decoded by
                a separate local process or SGE task.

Options:
  --beam         : type = float, default = 0.0
                   Viterbi search beam width.
  --gsf          : type = float, default = 1.0
                   Grammar scale factor.
  --lattice_info : type = string, default = "Atval"
                   HTK output lattice formating.
  --wip          : type = float, default = 0.0
                   Word insertion penalty.
  --word_net     : type = string, default = ""
                   Use this network (a.k.a. language model) to recognize the
                   utterances.
  --max_node_in  : type = integer, default = 1
                   Maximum node input degree.
  --max_nbests   : type = integer, default = 1
                   Maximum number of n-best decoding hypotheses.
  --qsub         : type = boolean, default = false
                   Run jobs in SGE using qsub.
  --qsub_opts    : type = string, default = ""
                   Other qsub options. Qsub may be called with additional
                   options added automatically, like "-cwd", "-t".
```