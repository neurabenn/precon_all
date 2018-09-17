#!/bin/bash 

######## this script is only meant to be run following brain extraction, denoising, Bias field correction and segmentation. 
######## This script is dependent on files generated in the previous outputs. 
#######  This is the beginning of Step 4 for surface generation i.e. filling. 
####### If you are unhappy with your surfaces then manually edit wm_orig.nii.gz and rerun this script and animal_tess.sh

Usage() {
    echo " "
    echo "Usage: `basename $0` [options] -i <T1_image> -x <Binary Mask>"
    echo ""
    echo " Compulsory Arguments "
    echo "-i <Denoised_Brain_T1_0N4.nii.gz>                  : Image must include nii or nii.gz file extension "
  

    echo " "
    echo " Optional Arguments"  ###### potentially add option to discard intermediate files? 
    echo "Example:  `basename $0` -i Denoised_Brain_T1_0N4.nii.gz -x pig_binary_mask.nii.gz "
    echo " "
    exit 1
}

if [ $# -lt 2 ] ; then Usage; exit 0; fi #### check that command is not called empty

NC=$(echo -en '\033[0m') #NC
RED=$(echo -en '\033[00;31m') #Red for error messages



####variables to be filled via options
img=""

#### parse them options
while getopts ":i:" opt ; do 
	case $opt in
		i) i=1;
			img=`echo $OPTARG`
			if [ ! -f ${img} ];then echo " "; echo " ${RED}CHECK INPUT FILE PATH ${NC}"; Usage; exit 1;fi ### check input file exists
			if [ "${img: -4}" == ".nii" ] || [ "${img: -7}" == ".nii.gz" ] ;then : ; else Usage; exit 1 ;fi
				;;
		\?)
		  echo "Invalid option:  -$OPTARG" >&2

		  	Usage
		  	exit 1
		  	;;

	esac 
done

echo ${img}


subj=$(dirname ${img}) 
echo ${subj}
cd $subj



T1=$(basename ${img})

#### making the brain mask image. Must be brain extracted
cp ${T1} mri/brainmask.nii.gz 

 cd mri/ 
if [ -f wm_orig.nii.gz ];then :; else  echo "Missing WM segmentation" `pwd`"/wm_orig.nii.gz";echo  "Pleas provide this required WM segmentation"; exit 1;fi
#### normalization of volume for use in freesurfer
upper=`fslstats brainmask -R | cut -d ' ' -f2-`
 echo "upper intensity value is " $upper 

 echo "############normalizing intensity values #########"



 fslmaths brainmask -div $upper -mul 150 nu -odt int

 fslmaths nu -mas wm_orig nu_wm

 fslmaths wm_orig -mul 110 wm_110

 fslmaths nu -sub nu_wm -add wm_110 brain -odt int

 cp brain.nii.gz brainmask.nii.gz

 echo "############# creating WM images for tesselation ###########"

 ### create WM image with sub_c intensity differences #####

 anat=`pwd`
 anat=${anat/mri/}$T1

echo $anat
pwd
 flirt -in ${PCP_PATH}standards/pig_brain.nii.gz -ref ${anat} -omat std2str.mat 

 convert_xfm -omat str2std.mat -inverse std2str.mat 

 mkdir transforms
lta_convert --infsl std2str.mat --outlta transforms/talairach.lta --src ${anat} --trg ${PCP_PATH}standards/pig_brain.nii.gz
lta_convert --infsl std2str.mat --outmni transforms/talairach.xfm --src ${anat} --trg ${PCP_PATH}standards/pig_brain.nii.gz


 ############# perform registration of allr equired masks for filling #########
  flirt -in ${PCP_PATH}standards/fill/sub_cort_std.nii.gz -ref ${anat}  -applyxfm -init std2str.mat -out sub_cort_str -interp nearestneighbour
  flirt -in ${PCP_PATH}standards/fill/non_cort_std.nii.gz -ref ${anat}  -applyxfm -init std2str.mat -out non_cort_str -interp nearestneighbour

 flirt -in ${PCP_PATH}standards/fill/left_hem -ref ${anat}  -applyxfm -init std2str.mat -out left_hem -interp nearestneighbour
  flirt -in ${PCP_PATH}standards/fill/right_hem -ref ${anat}  -applyxfm -init std2str.mat -out right_hem -interp nearestneighbour

 echo "######### filling WM ########"
 fslmaths wm_orig -sub sub_cort_str wm_nosubc
 fslmaths wm_nosubc -mul 110 wm_nosubc 
 fslmaths sub_cort_str -mul 250 -add wm_nosubc wm
 fslmaths wm_orig -add sub_cort_str -sub non_cort_str -thr 0 -bin  wm_pre_fill
 fslmaths wm_pre_fill -fillh wm_pre_fill

 fslmaths wm_pre_fill -mas left_hem -mul 255 wm_left
 fslmaths wm_pre_fill -mas right_hem -mul 127 wm_right
 fslmaths wm_left -add wm_right filled

 mri_convert brain.nii.gz  brain.mgz
 mri_convert brain.nii.gz  brainmask.mgz
 mri_convert brain.nii.gz  brain.finalsurfs.mgz
 mri_convert brain.nii.gz  T1.mgz
 mri_convert brain.nii.gz  nu.mgz
 mri_convert wm.nii.gz wm.mgz
 mri_convert filled.nii.gz filled.mgz 
 mri_convert wm_orig.nii.gz wm_orig.mgz

 mri_dir=${subj}mri


cd ${mri_dir}
 pwd
 mri_mask -T 5 brain.mgz brainmask.mgz brain.finalsurfs.mgz
 mri_pretess filled.mgz 255 T1.mgz filled-pretess255.mgz	
 mri_pretess filled.mgz 127 T1.mgz filled-pretess127.mgz


# rm *nii.gz