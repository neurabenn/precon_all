T1=$1
T2=$2
mask=$3
sigma=$4
odir=$(dirname $T1)/T1T2_mye
mkdir -p ${odir}
echo "start bias field correction"
imcp ${T1} ${odir}
imcp ${T2} ${odir}
imcp ${mask} ${odir}
# #### register the T1 and T2 images
$FSLDIR/bin/flirt -in ${T2} -ref ${T1} -dof 6 -out ${odir}/T2_reg
T1=$(basename ${T1})
mask=$(basename ${mask})
cd ${odir}

### implement bias field correction a la HCP
### Here we implement what lennart verhagen's hcp fork does
# ### https://github.com/lennartverhagen/Pipelines/blob/master/PreFreeSurfer/scripts/BiasFieldCorrection_sqrtT1wXT1w.sh
### this script differs in that it is meant to dovetail with the outputs of precon_all
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
