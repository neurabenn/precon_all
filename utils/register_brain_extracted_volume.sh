#!/bin/bash
# register_brain_extracted_volume.sh — user brain extracted images to get non linear warps
# precon_1 or precon_all -n should be run before running. 

set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") <precon_dir> <animal>

  precon_dir          path to existing precon_all output directory of which at least precon_1 or precon_all with the -n flag have been run
  animal              animal/template name (must exist in \$PCP_PATH/standards)

Requires \$PCP_PATH to be set.

Prior to running this script: 
 Run precon_1, or precon_all with
the -n flag, before running this — it sets up the directory structure that
this script writes into.

This script uses ANTs registration only, because FNIRT prefers a whole-head
image while ANTs is indifferent. Use this script only when you need
non-linear warps for a run that does not have a whole-head image, and you
must select one of the templates stored under \$PCP_PATH/standards.
EOF
    exit 1
}

if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; fi
if [[ $# -ne 2 ]]; then echo "ERROR: expected 2 arguments, got $#" >&2; usage; fi

precon_dir=$1
animal=$2

err() { echo "ERROR: $*" >&2; exit 1; }

[[ -n "${PCP_PATH:-}" ]]               || err "PCP_PATH not set"
[[ -d "$precon_dir" ]]                 || err "precon_dir not found: $PRECON_DIR"
[[ -d "$PCP_PATH/standards/$animal" ]] || err "no template dir for animal: $ANIMAL"

img_base=$(basename ${precon_dir})
T1=${img_base}.nii.gz

temp_brain=$PCP_PATH/standards/${animal}/extraction/${animal}_brain.nii.gz 
temp=$PCP_PATH/standards/${animal}/extraction/${animal}_temp.nii.gz 

echo $img_base
echo $T1

cd ${precon_dir}
fslmaths sanlm_${T1/.nii.gz/_brain}.nii.gz -mas ${img_base}_brain_mask.nii.gz ${img_base}_brain.nii.gz

flirt -in ${img_base}_brain.nii.gz -ref ${temp_brain} -omat mri/transforms/manual_fix.mat \
 -searchrx -180 180 -searchrz -180 180 -searchry -180 180


lta_convert --infsl mri/transforms/manual_fix.mat --outitk mri/transforms/manual_fix.txt \
 --src ${img_base}_brain.nii.gz --trg ${temp_brain}
ConvertTransformFile 3 mri/transforms/manual_fix.txt mri/transforms/manual_fix_ants.mat --convertToAffineType

fslmaths $PCP_PATH/standards/${animal}/extraction/brain_mask.nii.gz -bin mri/transforms/std_brain_mask.nii.gz


 ${ANTSPATH}/antsRegistrationSyN.sh -d 3 -f ${temp} -m sanlm_${T1/.nii.gz/_brain}.nii.gz -i mri/transforms/manual_fix_ants.mat \
    -x  mri/transforms/std_brain_mask.nii.gz,${T1/.nii.gz/_brain_mask.nii.gz} -o mri/transforms/ANTsREG
    
${PCP_PATH}/bin/ants_to_fsl_warp.sh ${temp} sanlm_${T1/.nii.gz/_brain}.nii.gz mri/transforms/ANTsREG1Warp.nii.gz mri/transforms/ANTsREG0GenericAffine.mat 