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

### This function computes the number of mixtures in the GMM at a given
### iteration, using a given mix_inc_scale scale factor.
### Examples:
###   $ compute_gmm_mix 1.5 5
###   8
###   $ compute_gmm_mix 1.5 6
###   12
function compute_gmm_mix () {
    [ $# -ne 2 ] && \
	echo "Usage: compute_gmm_mix <mix_inc_scale> <n>" >&2 && \
	return 1;
    python -c "
from math import ceil
n = 1
for i in xrange(1, $2):
  n = int(ceil(n * $1))
print n
"
    return 0;
}

### This function normalizes a floating point number.
### Examples:
### $ normalize_float 3
### 3.0
### $ normalize_float 133333333333333
### 1.33333333e+14
function normalize_float () {
    [ $# -ne 1 ] && echo "Usage: normalize_float <f>" >&2 && return 1;
    LC_NUMERIC=C printf "%.8g" "$1" | awk '{
    if(!match($0, /.+\..+/)) printf("%.1f\n", $0); else print $0; }';
    return 0;
}

### This function checkes whether a list of executables are available
### in the user's PATH or not.
### Examples:
### $ check_execs HERest cp
### $ check_execs HERest2 cp2
### ERROR: HERest2 is missing in your PATH!
### ERROR: cp2 is missing in your PATH!
function check_execs () {
    missing=0;
    for f in "$@"; do
	which "$f" &> /dev/null || { \
	    echo "ERROR: \"$f\" is missing in your PATH!" >&2 &&
	    missing=1;
	};
    done;
    return "$missing";
}

### This function creates a bunch of directories with mkdir -p and prints
### a friendly error message if any of them fails.
function make_dirs () {
    for f in "$@"; do
	mkdir -p "$f" || \
	    { echo "ERROR: Directory \"$f\" was not created!" >&2 && return 1; }
    done;
    return 0;
}
