#!/bin/bash 

head_img=$1
mask=$2

odir=$(dirname ${head_img})
echo ${odir}

base=$(basename ${head_img/.nii.gz/})
echo ${base}
 fslmaths ${head_img} -mas ${mask} ${odir}/${base}_brain_raw.nii.gz
# 
3dUnifize -overwrite -input ${odir}/${base}_brain_raw.nii.gz \
 -prefix ${odir}/${base}_brain_unifized.nii.gz \
 -ssave ${odir}/scale.nii.gz

fslmaths ${mask} -dilM -dilM ${odir}/dilated_brain_mask.nii.gz
fslmaths ${head_img} -mas ${odir}/dilated_brain_mask.nii.gz -binv ${odir}/invmask.nii.gz
fslmaths ${head_img} -mas ${odir}/invmask.nii.gz ${odir}/outside.nii.gz

out_max=$(fslstats ${odir}/outside.nii.gz -R | awk '{print $2}')
mean_brain_unifize=`fslstats ${odir}/${base}_brain_unifized.nii.gz  -P 90`

fslmaths ${odir}/outside.nii.gz -div ${out_max} -mul ${mean_brain_unifize} ${odir}/outside.nii.gz 

fslmaths ${odir}/${base}_brain_unifized.nii.gz -add ${odir}/outside.nii.gz ${odir}/${base}_unifized_head.nii.gz