#!/bin/bash 
### fix bet with manual mask 
### update template spaew rgistrations
### after running rerun preocn_all with precon_2
### only for use with templates defined in $PCP_PATH/standards
 
usage() {
    cat <<EOF
Usage: $(basename "$0") <precon_dir> <updated_brain_mask> <animal> <reg_method>
 
  precon_dir          path to existing precon_all output directory
  updated_brain_mask  path to manual/corrected brain mask
  animal              animal/template name (must exist in \$PCP_PATH/standards)
  reg_method          registration method: fsl | ants
 
Requires \$PCP_PATH to be set.
EOF
    exit 1
}
 
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then usage; fi
if [ $# -lt 4 ]; then echo "ERROR: missing arguments"; usage; fi
 
precon_dir=$1
updated_brain_mask=$2
animal=$3
reg_method=$4

img_base=$(basename ${precon_dir})
T1=${img_base}.nii.gz

echo $img_base
echo $T1
cp ${updated_brain_mask} ${precon_dir}/${T1/.nii.gz/_brain_mask.nii.gz}

cd ${precon_dir}
fslmaths sanlm_${T1} -mas ${img_base}_brain_mask.nii.gz ${img_base}_brain.nii.gz

temp_brain=$PCP_PATH/standards/${animal}/extraction/${animal}_brain.nii.gz 
temp=$PCP_PATH/standards/${animal}/extraction/${animal}_temp.nii.gz 

flirt -in ${img_base}_brain.nii.gz -ref ${temp_brain} -omat mri/transforms/manual_fix.mat \
 -searchrx -180 180 -searchrz -180 180 -searchry -180 180


lta_convert --infsl mri/transforms/manual_fix.mat --outitk mri/transforms/manual_fix.txt \
 --src ${img_base}_brain.nii.gz --trg ${temp_brain}
ConvertTransformFile 3 mri/transforms/manual_fix.txt mri/transforms/manual_fix_ants.mat --convertToAffineType

fslmaths $PCP_PATH/standards/${animal}/extraction/brain_mask.nii.gz -bin mri/transforms/std_brain_mask.nii.gz

if [ "${reg_method}" == "fsl" ];then 
    $FSLDIR/bin/fnirt --in=sanlm_${T1} --ref=${temp}  \
    --cout=mri/transforms/str2std_warp --aff=mri/transforms/manual_fix.mat \
    --inmask=${T1/.nii.gz/_brain_mask.nii.gz} --refmask=mri/transforms/std_brain_mask.nii.gz
    
    $FSLDIR/bin/invwarp --warp=mri/transforms/str2std_warp --ref=sanlm_${T1} --out=mri/transforms/std2str_warp

else

    ${ANTSPATH}/antsRegistrationSyN.sh -d 3 -f ${temp} -m sanlm_${T1} -i mri/transforms/manual_fix_ants.mat \
    -x  mri/transforms/std_brain_mask.nii.gz,${T1/.nii.gz/_brain_mask.nii.gz} -o mri/transforms/ANTsREG
    
    ${PCP_PATH}/bin/ants_to_fsl_warp.sh ${temp} sanlm_${T1} mri/transforms/ANTsREG1Warp.nii.gz mri/transforms/ANTsREG0GenericAffine.mat 
fi 
