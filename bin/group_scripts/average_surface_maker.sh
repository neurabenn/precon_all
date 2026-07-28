#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  make_average_surface_native.sh \
    --template-ref /path/to/template_subject \
    --subject-list /path/to/group.txt \
    --out-dir /path/to/output_subject \
    --ico 5 \
    [--include-ref-stats] \
    [--stats]

Description:
  Builds an average FreeSurfer surface subject from a template subject and a
  newline-delimited list of precon_all subject directories.

Required arguments:
  --template-ref   Precon_all subject directory used as the reference subject.
  --subject-list   Text file containing one subject directory per line.
  --out-dir        Output average-subject directory to create.
  --ico            Icosahedral order for surface averaging.

Optional arguments:
  --include-ref-stats
                   Include the reference subject in list.subjects.txt so it is
                   used for stats and annotation averaging as well.
  --stats          Compute thickness, sulc, and curv averages and std maps.
  -h, --help       Show this help text.

Notes:
  - Run from the directory that should act as SUBJECTS_DIR.
  - The output subject name is derived from basename(out-dir).
  - The template subject is appended to the averaging list automatically.
EOF
}

die() {
  echo "ERROR: $*" >&2
  usage
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing file: $1"
}

require_dir() {
  [[ -d "$1" ]] || die "missing directory: $1"
}

template_ref=""
subject_list_file=""
out_dir=""
ico=""
include_ref_stats=0
do_stats=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template-ref)
      [[ $# -ge 2 ]] || die "--template-ref requires an argument"
      template_ref=$2
      shift 2
      ;;
    --subject-list)
      [[ $# -ge 2 ]] || die "--subject-list requires an argument"
      subject_list_file=$2
      shift 2
      ;;
    --out-dir)
      [[ $# -ge 2 ]] || die "--out-dir requires an argument"
      out_dir=$2
      shift 2
      ;;
    --ico)
      [[ $# -ge 2 ]] || die "--ico requires an argument"
      ico=$2
      shift 2
      ;;
    --include-ref-stats)
      include_ref_stats=1
      shift
      ;;
    --stats)
      do_stats=1
      shift
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

[[ -n "$template_ref" ]] || die "--template-ref is required"
[[ -n "$subject_list_file" ]] || die "--subject-list is required"
[[ -n "$out_dir" ]] || die "--out-dir is required"
[[ -n "$ico" ]] || die "--ico is required"

require_dir "$template_ref"
require_file "$subject_list_file"
require_dir "${template_ref}/mri"
require_file "${template_ref}/mri/brain.mgz"
require_file "${template_ref}/mri/rawavg.nii.gz"

[[ -n "${FREESURFER_HOME:-}" ]] || die "FREESURFER_HOME is not set"
require_dir "$FREESURFER_HOME"

SUBJECTS_DIR=$(pwd)
avg=$(basename "$out_dir")
out_dir=$(cd "$(dirname "$out_dir")" && pwd)/$(basename "$out_dir")
template_subject_list="${out_dir}/scripts/template_subject_list.txt"
final_subject_list="${out_dir}/list.subjects.txt"

mkdir -p "${out_dir}"/{surf,mri,label,scripts}

echo "SUBJECTS_DIR=${SUBJECTS_DIR}"
echo "template_ref=${template_ref}"
echo "out_dir=${out_dir}"
echo "avg=${avg}"
echo "ico=${ico}"
echo "include_ref_stats=${include_ref_stats}"
echo "do_stats=${do_stats}"

### this remains high res -- true volumetric template anatomy
mri_convert "${template_ref}/mri/rawavg.nii.gz" "${out_dir}/mri/rawavg.mgz"
mri_add_xform_to_header -c auto \
  "${out_dir}/mri/rawavg.mgz" \
  "${out_dir}/mri/rawavg.mgz"

### make average brain FS style?
### this here becomes the simple freesurfer average one?

mapfile -t subjects < "$subject_list_file"
[[ ${#subjects[@]} -gt 0 ]] || die "subject list is empty: $subject_list_file"

: > "$template_subject_list"
: > "$final_subject_list"
for subj in "${subjects[@]}"; do
  [[ -n "$subj" ]] || continue
  echo "$subj" >> "$template_subject_list"
  echo "$subj" >> "$final_subject_list"
done
echo "$template_ref" >> "$template_subject_list"
if [[ $include_ref_stats -eq 1 ]]; then
  echo "$template_ref" >> "$final_subject_list"
fi

mapfile -t template_subjects < "$template_subject_list"


### volumetric template
### make average brain FS style from transformed brain volumes
tmpdir="${out_dir}/tmp_average_brain"
mkdir -p "$tmpdir"
trap 'rm -rf "$tmpdir"' EXIT

xfmvols=()
n=0
for subject in "${subjects[@]}"; do
  [[ -n "$subject" ]] || continue

  invol="${SUBJECTS_DIR}/${subject}/mri/brain.mgz"
  xfm="${SUBJECTS_DIR}/${subject}/mri/transforms/talairach.xfm"
  xfmvol="${tmpdir}/brain.${n}.mgz"

  require_file "$invol"
  require_file "$xfm"

  mri_convert "$invol" "$xfmvol" --apply_transform "$xfm" -oc 0 0 0
  xfmvols+=("$xfmvol")
  n=$((n + 1))
done

[[ ${#xfmvols[@]} -gt 0 ]] || die "no subject volumes were processed"

mri_average -noconform "${xfmvols[@]}" "${out_dir}/mri/brain.mgz"
mri_add_xform_to_header -c auto "${out_dir}/mri/brain.mgz" "${out_dir}/mri/brain.mgz"

cp "${out_dir}/mri/brain.mgz" "${out_dir}/mri/orig.mgz"
cp "${out_dir}/mri/brain.mgz" "${out_dir}/mri/T1.mgz"
cp "${out_dir}/mri/brain.mgz" "${out_dir}/mri/brainmask.mgz"
cp "${out_dir}/mri/brain.mgz" "${out_dir}/mri/mni305.cor.mgz"



mris_make_template -norot lh sphere.reg "${template_subjects[@]}" "${out_dir}/lh.reg.template.tif"
mris_make_template -norot rh sphere.reg "${template_subjects[@]}" "${out_dir}/rh.reg.template.tif"

for surf in orig white graymid pial; do
  for hemi in lh rh; do
    mris_make_average_surface \
      -nonorm \
      -i "$ico" \
      -o "$surf" \
      -sdir-out "$SUBJECTS_DIR" \
      "$hemi" \
      "$surf" \
      sphere.reg \
      "$avg" \
      "${template_subjects[@]}"
  done
done

if [[ "$ico" == "7" ]]; then
  cp "${FREESURFER_HOME}/average/surf/lh.sphere.reg" "${out_dir}/surf/lh.sphere"
  cp "${FREESURFER_HOME}/average/surf/rh.sphere.reg" "${out_dir}/surf/rh.sphere"
else
  cp "${FREESURFER_HOME}/average/surf/lh.sphere.ico${ico}.reg" "${out_dir}/surf/lh.sphere"
  cp "${FREESURFER_HOME}/average/surf/rh.sphere.ico${ico}.reg" "${out_dir}/surf/rh.sphere"
fi

cp "${out_dir}/surf/lh.sphere" "${out_dir}/surf/lh.sphere.reg"
cp "${out_dir}/surf/rh.sphere" "${out_dir}/surf/rh.sphere.reg"
cp "${out_dir}/surf/lh.sphere" "${out_dir}/surf/lh.${avg}.sphere.reg"
cp "${out_dir}/surf/rh.sphere" "${out_dir}/surf/rh.${avg}.sphere.reg"

mris_smooth -nw -n 5 "${out_dir}/surf/lh.white" "${out_dir}/surf/lh.smoothwm"
mris_smooth -nw -n 5 "${out_dir}/surf/rh.white" "${out_dir}/surf/rh.smoothwm"

inflate_iters=15
if [[ "$ico" -le 5 ]]; then
  inflate_iters=2
fi

mris_inflate -dist .01 -f .001 -no-save-sulc -n "$inflate_iters" \
  "${out_dir}/surf/lh.smoothwm" "${out_dir}/surf/lh.inflated"
mris_inflate -dist .01 -f .001 -no-save-sulc -n "$inflate_iters" \
  "${out_dir}/surf/rh.smoothwm" "${out_dir}/surf/rh.inflated"

### use label form template brain. 
for hemi in lh rh; do
  mri_label2label \
    --srclabel "${template_ref}/label/${hemi}.cortex.label" \
    --srcsubject "$template_ref" \
    --trglabel "${out_dir}/label/${hemi}.cortex.label" \
    --trgsubject "$avg" \
    --hemi "$hemi" \
    --regmethod surface
done

if [[ $do_stats -eq 1 ]]; then
  for hemi in lh rh; do
    for meas in thickness sulc curv; do
      mris_preproc \
        --out "${out_dir}/surf/stack.${hemi}.${meas}.mgh" \
        --f "$final_subject_list" \
        --target "$avg" \
        --hemi "$hemi" \
        --meas "$meas" --srcsurfreg sphere.reg

      mri_concat "${out_dir}/surf/stack.${hemi}.${meas}.mgh" \
        --mean --o "${out_dir}/surf/${hemi}.${meas}.avg.mgh"

      mri_concat "${out_dir}/surf/stack.${hemi}.${meas}.mgh" \
        --std --o "${out_dir}/surf/std.${hemi}.${meas}.mgh"

      mri_surf2surf \
        --sval "${out_dir}/surf/${hemi}.${meas}.avg.mgh" \
        --s "$avg" \
        --tval "${out_dir}/surf/${hemi}.${meas}" \
        --trg_type curv \
        --hemi "$hemi"
    done
  done
fi

 $PCP_PATH/bin/group_scripts/consensus_label.sh --subject ${avg} --hemi lh 
 $PCP_PATH/bin/group_scripts/consensus_label.sh --subject ${avg} --hemi rh 

### Recompute stats after consensus_label.sh replaces the provisional merged
### cortex/subcortex labels. The first pass gets the pipeline through the initial
### cortex-label requirement; this second pass makes the final stats consistent
### with the refined average-subject labels.

if [[ $do_stats -eq 1 ]]; then
  for hemi in lh rh; do
    for meas in thickness sulc curv; do
      mris_preproc \
        --out "${out_dir}/surf/stack.${hemi}.${meas}.mgh" \
        --f "$final_subject_list" \
        --target "$avg" \
        --hemi "$hemi" \
        --meas "$meas" --srcsurfreg sphere.reg

      mri_concat "${out_dir}/surf/stack.${hemi}.${meas}.mgh" \
        --mean --o "${out_dir}/surf/${hemi}.${meas}.avg.mgh"

      mri_concat "${out_dir}/surf/stack.${hemi}.${meas}.mgh" \
        --std --o "${out_dir}/surf/std.${hemi}.${meas}.mgh"

      mri_surf2surf \
        --sval "${out_dir}/surf/${hemi}.${meas}.avg.mgh" \
        --s "$avg" \
        --tval "${out_dir}/surf/${hemi}.${meas}" \
        --trg_type curv \
        --hemi "$hemi"
    done
  done
fi

ln -sf ${out_dir}/label/lh.subcortex.label ${avg}/label/lh.Unknown.label
ln -sf ${out_dir}/label/rh.subcortex.label ${avg}/label/rh.Unknown.label

mris_label2annot --s ${avg}  --h lh --ctab $PCP_PATH/standards/cort.annot.ctab --l ${out_dir}/label/lh.Unknown.label --l ${out_dir}/label/lh.cortex.label --surf white --a Cortex
mris_label2annot --s ${avg}  --h rh --ctab $PCP_PATH/standards/cort.annot.ctab --l ${out_dir}/label/rh.Unknown.label --l ${out_dir}/label/rh.cortex.label --surf white --a Cortex



echo "Average surface subject created at ${out_dir}"