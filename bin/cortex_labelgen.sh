#!/bin/bash 
Usage() {
    echo " "
    echo "Usage: `basename $0` [options] -s <Subject folder> "
    echo ""
    echo " Compulsory Arguments "
    echo "-s <subject directory>                  : preprocesed directory containing all surface and fill files"
 	
    echo " " ##############potentially add opption to choose segmentation approach i.e ANTS or FAST############# 
    echo "Example:  `basename $0` -s pig_T1.nii.gz "
    echo " "
    exit 1
}
if [ $# -lt 2 ] ; then Usage; exit 0; fi #### check that command is not called empty

NC=$(echo -en '\033[0m') #NC
RED=$(echo -en '\033[00;31m') #Red for error messages

subj=""
thresh=""
#### parse them options
while getopts ":s:" opt ; do 
	case $opt in
		s)
			s=1;
			subj=`echo $OPTARG`
			if [ ! -d ${subj} ];then echo " "; echo " ${RED}CHECK INPUT DIRECTORY ${NC}"; Usage; exit 1;fi ### check input file exists

			#if [ "${img: -4}" == ".nii" ] || [ "${img: -7}" == ".nii.gz" ] ;then : ; else Usage; exit 1 ;fi
				;;
		\?)
		  echo "Invalid option:  -$OPTARG" 

		  	Usage
		  	exit 1
		  	;;

	esac 
done

SUBJECTS_DIR=`pwd`

 mkdir ${subj}label
 mkdir ${subj}mri/cort_labels
cd ${subj}mri/
## do the left side
fslmaths wm_left.nii.gz -mas sub_cort_str.nii.gz cort_labels/subc_left
fslmaths wm_left.nii.gz -sub cort_labels/subc_left -bin cort_labels/wm_left_cort
fslmaths cort_labels/wm_left_cort -dilM cort_labels/wm_left_cort_dil #### dilate the label to remove spotting of mask
fslmaths cort_labels/wm_left_cort_dil -mul 2  cort_labels/wm_left_cort_dil


## now the right side

fslmaths wm_right.nii.gz -mas sub_cort_str.nii.gz cort_labels/subc_right
fslmaths wm_right.nii.gz -sub cort_labels/subc_right -bin cort_labels/wm_right_cort
fslmaths cort_labels/wm_right_cort -dilM cort_labels/wm_right_cort_dil

##gen whole brain wm labels

fslmaths cort_labels/wm_left_cort_dil -add cort_labels/wm_right_cort_dil cort_labels/wm_labels

###time to convert these volumes to surface labels
echo "volumes created. converting to surfae labels"
## left first
cd cort_labels/

	echo mri_convert wm_labels.nii.gz wm_labels.mgz
	pwd
	mri_convert wm_labels.nii.gz wm_labels.mgz
	pwd
	

	mri_vol2label --i wm_labels.mgz  --id 1 --v wm_labels.mgz --l rh.cort.label
	# echo ""
	# pwd
	mri_label2vol --label rh.cort.label --temp ../brain.mgz  --o rh.cort_vol.mgz --identity


	mri_vol2surf --mov rh.cort_vol.mgz  --ref brain.mgz --hemi rh --o rh.cort_srf.mgh --regheader ${subj}

	mri_vol2label --i rh.cort_srf.mgh --id 1 --surf ${subj}  rh --l ../../label/rh.cortex

	
	mri_convert wm_labels.nii.gz wm_labels.mgz

	mri_vol2label --i wm_labels.mgz  --id 2 --v wm_labels.mgz --l lh.cort.label
	# echo ""
	# pwd
	mri_label2vol --label lh.cort.label --temp ../brain.mgz  --o lh.cort_vol.mgz --identity


	mri_vol2surf --mov lh.cort_vol.mgz  --ref brain.mgz --hemi lh --o lh.cort_srf.mgh --regheader ${subj}

	mri_vol2label --i lh.cort_srf.mgh --id 1 --surf ${subj}  lh --l ../../label/lh.cortex


























