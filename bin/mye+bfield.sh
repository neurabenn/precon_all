#!/bin/bash 
####### script to make myelin maps inserted into precon_all 
T1=$1 ### T1 image
T2=$2 ### T2 image 
mask=$3 ### brain mask in T1 space
sigma=$4 #### sigma to smooth for bias field correction
odir=$(dirname $T1)/T1T2_mye
mkdir -p ${odir}
echo "start bias field correction"
imcp ${T1} ${odir}
imcp ${T2} ${odir}
imcp ${mask} ${odir}

cd ${odir}
mkdir -p fast_seg 
mkdir -p transforms

T1=$(basename $T1)
T2=$(basename $T2)
mask=$(basename $mask)
# #### register the whole body T1 and T2 images
echo $T1
### run initial reg to speed up BBR
echo "first flirt"
$FSLDIR/bin/flirt -in ${T2} -ref ${T1} -dof 6 -out T2_reg -omat transforms/T2_reg.mat -cost mutualinfo -interp spline
$FSLDIR/bin/convert_xfm -omat transforms/T1_toT2.mat -inverse  transforms/T2_reg.mat 

# echo $FSLDIR/bin/fslmaths ${T1} -mas ${mask} ${T1/.nii.gz/_brain}
# $FSLDIR/bin/fslmaths ${T1} -mas ${mask} ${T1/.nii.gz/_brain}

# $FSLDIR/bin/fslmaths ${T2} -mas ${mask} ${T2/.nii.gz/_brain}
# echo "running fast"

# $FSLDIR/bin/fast -o fast_seg/quick_seg -n 3 ${T1/.nii.gz/_brain} 
# $FSLDIR/bin/fslmaths fast_seg/*pve_2.nii.gz -thr 0.5 -bin quick_wm_seg 
# echo "running bbr flirt "
# $FSLDIR/bin/flirt -in ${T2/.nii.gz/_brain} -ref  ${T1/.nii.gz/_brain} -cost bbr -wmseg quick_wm_seg -init transforms/T2_reg_init.mat -dof 6 -out T2_reg -omat transforms/T2_reg.mat 
# echo $FSLDIR/bin/applywarp --in=${T2} --ref=${T1} --out=T2_reg --premat=transforms/T2_reg.mat
# $FSLDIR/bin/applywarp --in=${T2} --ref=${T1} --out=T2_reg --premat=transforms/T2_reg.mat



## implement bias field correction a la HCP
## Here we implement what lennart verhagen's hcp fork does
### https://github.com/lennartverhagen/Pipelines/blob/master/PreFreeSurfer/scripts/BiasFieldCorrection_sqrtT1wXT1w.sh
## this script differs in that it is meant to dovetail with the outputs of precon_all
#### sqrt T1 x T2 normalized by mean
${FSLDIR}/bin/fslmaths ${T1} -mul T2_reg -abs -sqrt T1xT2.nii.gz -odt float
${FSLDIR}/bin/fslmaths T1xT2.nii.gz -mas ${mask} T1xT2_brain.nii.gz
mu_brain=`$FSLDIR/bin/fslstats T1xT2_brain.nii.gz -M`
${FSLDIR}/bin/fslmaths T1xT2_brain.nii.gz -div ${mu_brain} T1xT2_brain_norm.nii.gz
#### smooth the outputs
${FSLDIR}/bin/fslmaths T1xT2_brain_norm.nii.gz -bin -s ${sigma} smoothNorm_${sigma}.nii.gz
${FSLDIR}/bin/fslmaths T1xT2_brain_norm.nii.gz -s ${sigma} -div smoothNorm_${sigma}.nii.gz T1xT2_brain_norm_s${sigma}.nii.gz
#### basic bfirled correctoin dividing norm sqrt by smoothed

${FSLDIR}/bin/fslmaths T1xT2_brain_norm.nii.gz -div T1xT2_brain_norm_s${sigma}.nii.gz T1xT2_brain_norm_modulate.nii.gz

# Create mask using thresholding Mean - 0.5*Stddev, remove non-grey/white tissue.
STD=`${FSLDIR}/bin/fslstats T1xT2_brain_norm_modulate.nii.gz -S`
echo ${STD}
MU=`${FSLDIR}/bin/fslstats T1xT2_brain_norm_modulate.nii.gz -M`
echo ${MU}
low=`echo "${MU} - (${STD} * 0.5)" | bc -l`
echo ${low}
${FSLDIR}/bin/fslmaths T1xT2_brain_norm_modulate -thr $low -bin -ero -mul 255 T1xT2_brain_norm_modulate_mask
wb_command -volume-remove-islands T1xT2_brain_norm_modulate_mask.nii.gz T1xT2_brain_norm_modulate_mask.nii.gz

###### Extrapolate normalised sqrt image from mask region out to whole FOV
${FSLDIR}/bin/fslmaths T1xT2_brain_norm.nii.gz -mas T1xT2_brain_norm_modulate_mask.nii.gz -dilall bias_raw.nii.gz -odt float
${FSLDIR}/bin/fslmaths bias_raw.nii.gz -s ${sigma} T1xT2_bias_field

#### correct the images
${FSLDIR}/bin/fslmaths ${T1} -div T1xT2_bias_field -mas ${mask} T1_restored_brain -odt float
${FSLDIR}/bin/fslmaths ${T1} -div T1xT2_bias_field  T1_restored -odt float
${FSLDIR}/bin/fslmaths T2_reg -div T1xT2_bias_field -mas ${mask} T2_restored_brain -odt float
${FSLDIR}/bin/fslmaths T2_reg -div T1xT2_bias_field  T2_restored -odt float
echo "end bias field correction"
wb_command -volume-math "clamp((T1w / T2w), 0, 100)" T1wDividedByT2w.nii.gz -var T1w T1_restored_brain.nii.gz \
-var T2w T2_restored_brain.nii.gz -fixnan 0
wb_command -volume-palette T1wDividedByT2w.nii.gz MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false

echo "end volumetric mylein mapping"





