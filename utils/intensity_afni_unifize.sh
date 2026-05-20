usage() {
    cat <<EOF
Usage: $(basename "$0") <precon_dir> [animal]

  precon_dir          Path to an existing precon_all output directory
  animal              Optional animal/template name under \$PCP_PATH/standards

This script is for cases where standard N4 bias correction is not enough.
It can be useful for T1 images with substantial signal drift, especially when
the temporal poles have intensities close to superior CSF.

The script runs AFNI 3dUnifize, so AFNI must be installed and available on PATH.

If [animal] is provided, the script will also update template-space
registrations using the intensity-normalized, brain-extracted image.

Warp updates are done with ANTs only. FNIRT is not used here because it is
intended for whole-head registration, whereas this workflow uses a brain-extracted image.

Examples:
  $(basename "$0") /path/to/subj_precon
  $(basename "$0") /path/to/subj_precon macaque
EOF
    exit 1
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
fi

if [ $# -ne 1 ] && [ $# -ne 2 ]; then
    echo "ERROR: expected either 1 argument or 2 arguments"
    usage
fi

precon_dir=$1
animal=${2:-}

if [ -n "${animal}" ]; then
    echo "Updating registration using ${animal} template with ANTs"
fi

if ! command -v 3dUnifize >/dev/null 2>&1; then
    echo "ERROR: 3dUnifize not found. AFNI is required but not installed or not on PATH."
    exit 1
fi

precon_dir=$1
cd ${precon_dir}

img=$(basename ${precon_dir})_brain.nii.gz
echo $img
mv ${img} ${img/.nii.gz/_orig.nii.gz}
3dUnifize -input ${img/.nii.gz/_orig.nii.gz} -prefix ${img} 

fslmaths ${img} -mas ${img/.nii.gz/_mask.nii.gz} ${img} 
cp ${img} sanlm_${img/.nii.gz/_0N4.nii.gz}
cp ${img} mri/rawavg.nii.gz

if [ -n "${animal}" ]; then
    echo "${animal}"
    temp=${PCP_PATH}/standards/${animal}/extraction/${animal}_brain.nii.gz
    temp_mask=${PCP_PATH}/standards/${animal}/extraction/brain_mask.nii.gz
     fslmaths ${temp_mask} -bin mri/transforms/std_brain_mask.nii.gz
     ${ANTSPATH}/antsRegistrationSyN.sh -d 3 -f ${temp} -m ${img} \
    -x  mri/transforms/std_brain_mask.nii.gz,${img/.nii.gz/_brain_mask.nii.gz} -o mri/transforms/ANTsREG
    ${PCP_PATH}/bin/ants_to_fsl_warp.sh ${temp} ${img} mri/transforms/ANTsREG1Warp.nii.gz mri/transforms/ANTsREG0GenericAffine.mat    
fi
