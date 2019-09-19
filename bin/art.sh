#!/bin/bash 

brain_dir=`pwd`
dimNC=`fslinfo  mri/non_cort |grep 'pixdim1'|awk '{print $2}'`
dimgray=`fslinfo seg/seg_pve_1.nii.gz |grep 'pixdim1'|awk '{print $2}'` 

    if [ `echo "${dimNC} == ${dimgray}"|bc -l` -eq 1  ];then 
        echo "all good"
        $FSLDIR/bin/imcp seg/seg_pve_1.nii.gz mri/gray 
    else
        echo "resampling GM seg for masking"
        $FSLDIR/bin/flirt -in seg/seg_pve_1.nii.gz -ref seg/seg_pve_1.nii.gz -out mri/gray -applyisoxfm ${dimNC}
    fi

cd ${brain_dir}/mri
$FSLDIR/bin/fslmaths non_cort -thr 0.5 -bin -mas gray  -bin cb_gray


$FSLDIR/bin/fslmaths wm_orig.nii.gz -mas non_cort -bin cb_white


$FSLDIR/bin/fslmaths cb_white -mas left_hem L_cb_white

$FSLDIR/bin/fslmaths cb_white -mas right_hem R_cb_white

$FSLDIR/bin/fslmaths cb_gray -mas left_hem -add L_cb_white -bin L_cb_gray

$FSLDIR/bin/fslmaths cb_gray -mas right_hem -add R_cb_white -bin R_cb_gray

cd ${brain_dir}/surf/
mri_tessellate ../mri/L_cb_white.nii.gz 1 lh.cb_white
mri_tessellate ../mri/L_cb_gray.nii.gz 1 lh.cb_gray
mri_tessellate ../mri/R_cb_gray.nii.gz 1 rh.cb_gray
mri_tessellate ../mri/R_cb_white.nii.gz 1 rh.cb_white

for i in `ls *cb*`;do 
     mris_extract_main_component ${i} ${i}
    mris_smooth -nw -n 3 ${i} ${i}
    mris_convert ${i} ${i}.gii
done

for i in lh rh;do 
    mris_convert ${i}.pial ${i}.pial.gii
    mris_convert ${i}.white ${i}.white.gii
done
 

$PCP_PATH/bin/cpMDgifti.sh lh.pial.gii lh.cb_gray.gii
$PCP_PATH/bin/cpMDgifti.sh rh.pial.gii rh.cb_gray.gii
$PCP_PATH/bin/cpMDgifti.sh rh.white.gii rh.cb_white.gii

for i in lh rh;do 
    for j in pial white;do
        mris_smooth -nw -n 6 ${i}.${j}.gii ${i}.${j}.art.gii
        mris_convert ${i}.${j}.art.gii ${i}.${j}.art.stl
    done
done


for i in `ls *cb*gii`;do 
    mris_convert ${i} ${i/.gii/.stl}
done

mris_convert --combinesurfs lh.pial.art.gii lh.cb_gray.gii lh.full.stl
mris_convert --combinesurfs lh.white.art.gii lh.cb_white.gii lh.Wfull.stl
mris_convert --combinesurfs rh.pial.art.gii rh.cb_gray.gii rh.full.stl
mris_convert --combinesurfs rh.white.art.gii rh.cb_white.gii rh.Wfull.stl
