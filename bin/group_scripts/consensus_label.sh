#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  consensus_label.sh --subject SUBJECT --hemi lh|rh [--subjects-dir DIR] [--surf white]

Description:
  Creates ?h.subcortex.label from vertices where ?h.curv == 0 and
  ?h.cortex.label from all other vertices, for one hemisphere.

Required arguments:
  --subject        Subject name inside SUBJECTS_DIR.
  --hemi           Hemisphere: lh or rh.

Optional arguments:
  --subjects-dir   Override SUBJECTS_DIR. Default: current SUBJECTS_DIR env var.
  --surf           Surface used for label xyz coordinates. Default: white
  -h, --help       Show this help text.

Outputs:
  $SUBJECTS_DIR/$SUBJECT/label/?h.subcortex.label
  $SUBJECTS_DIR/$SUBJECT/label/?h.cortex.label
EOF
}

die() {
  echo "ERROR: $*" >&2
  usage
  exit 1
}

subject=""
hemi=""
subjects_dir="${SUBJECTS_DIR:-}"
surf="white"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --subject)
      [[ $# -ge 2 ]] || die "--subject requires an argument"
      subject=$2
      shift 2
      ;;
    --hemi)
      [[ $# -ge 2 ]] || die "--hemi requires an argument"
      hemi=$2
      shift 2
      ;;
    --subjects-dir|--sd)
      [[ $# -ge 2 ]] || die "--subjects-dir requires an argument"
      subjects_dir=$2
      shift 2
      ;;
    --surf)
      [[ $# -ge 2 ]] || die "--surf requires an argument"
      surf=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unrecognized argument: $1"
      ;;
  esac
done

[[ -n "$subject" ]] || die "--subject is required"
[[ -n "$hemi" ]] || die "--hemi is required"

case "$hemi" in
  lh|rh) ;;
  *) die "--hemi must be 'lh' or 'rh'" ;;
esac

[[ -n "$subjects_dir" ]] || die "SUBJECTS_DIR is not set and --subjects-dir was not provided"
[[ -d "$subjects_dir" ]] || die "subjects dir not found: $subjects_dir"
[[ -d "$subjects_dir/$subject" ]] || die "subject not found: $subjects_dir/$subject"

curv="$subjects_dir/$subject/surf/${hemi}.curv"
label_dir="$subjects_dir/$subject/label"
zero_mask="$subjects_dir/$subject/surf/${hemi}.curv.zero.mgh"
nonzero_mask="$subjects_dir/$subject/surf/${hemi}.curv.nonzero.mgh"
subcortex_label="$label_dir/${hemi}.subcortex.label"
cortex_label="$label_dir/${hemi}.cortex.label"

[[ -f "$curv" ]] || die "missing curv file: $curv"
mkdir -p "$label_dir"

mri_binarize --i "$curv" --match 0 --o "$zero_mask"
mri_binarize --i "$curv" --match 0 --inv --o "$nonzero_mask"

mri_cor2label \
  --i "$zero_mask" \
  --surf "$subject" "$hemi" "$surf" \
  --id 1 \
  --l "$subcortex_label"

mri_cor2label \
  --i "$nonzero_mask" \
  --surf "$subject" "$hemi" "$surf" \
  --id 1 \
  --l "$cortex_label"

echo "Wrote:"
echo "  $subcortex_label"
echo "  $cortex_label"