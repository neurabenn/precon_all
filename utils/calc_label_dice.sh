#!/bin/bash
set -euo pipefail

err() {
    echo "ERROR: $*" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: $(basename "$0") <subject> <hemi> <label1> <label2>

Print Overall Dice from mris_compute_parc_overlap.

Arguments:
  subject  FreeSurfer subject ID or subject directory
  hemi     lh or rh
  label1   first label stem, e.g. cortex or subcortex
  label2   second label stem, e.g. cortex.transferred label

Notes:
  If subject is a relative path under the current directory, SUBJECTS_DIR is
  set to the current directory and --s is kept as that relative path.
EOF
    exit 1
}

[[ $# -eq 4 ]] || usage

subj_arg=${1%/}
hemi=$2
label1=$3
label2=$4

[[ "$hemi" == "lh" || "$hemi" == "rh" ]] || err "hemi must be lh or rh (got '$hemi')"

cwd=$(pwd -P)

if [[ -d "$cwd/$subj_arg" ]]; then
    SUBJECTS_DIR=$cwd
    subject=$subj_arg
elif [[ -n "${SUBJECTS_DIR:-}" && -d "$SUBJECTS_DIR/$subj_arg" ]]; then
    subject=$subj_arg
elif [[ -d "$subj_arg" ]]; then
    abs_subj=$(cd "$subj_arg" && pwd -P)
    SUBJECTS_DIR=$(cd "$(dirname "$abs_subj")" && pwd -P)
    subject=$(basename "$abs_subj")
else
    err "cannot find subject '$subj_arg' under pwd or SUBJECTS_DIR"
fi

export SUBJECTS_DIR

mris_compute_parc_overlap \
    --s "$subject" \
    --hemi "$hemi" \
    --label1 "$label1" \
    --label2 "$label2" |
    awk -F'= ' '/Overall Dice/ {print $2; found=1} END {exit found ? 0 : 1}'
