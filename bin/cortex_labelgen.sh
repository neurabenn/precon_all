#!/bin/bash 
source $FREESURFER_HOME/SetUpFreeSurfer.sh
Usage() {
    echo " "
    echo "Usage: `basename $0` [options] -s <Subject folder> "
    echo ""
    echo " Compulsory Arguments "
    echo "-s <subject directory>                  : preprocesed directory containing all surface and fill files"
    echo " Optional Arguments"
    echo " -L only create left cortex labels"
    echo " -R only create left cortex labels"
 	
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
L_only=""
R_only=""
#### parse them options
while getopts ":s:LR" opt ; do 
	case $opt in
		s)
			s=1;
			subj=`echo $OPTARG`
			if [ ! -d ${subj} ];then echo " "; echo " ${RED}CHECK INPUT DIRECTORY ${NC}"; Usage; exit 1;fi ### check input file exists
				;;
     L)
          L_only="y"
                ;;
      R)  R=1
          R_only="y"
                ;;
		\?)
		  echo "Invalid option:  -$OPTARG" >&2

		  	Usage
		  	exit 1
		  	;;

	esac 
done


side=(left right)
if [[ ${L_only} == "y" ]];then echo "Left only"; side=(left);fi
if [[ ${R_only} == "y" ]];then echo "Right only "; side=(right);fi
echo ${side[*]}

hemi=(lh rh)
if [[ ${L_only} == "y" ]];then echo "LH only"; hemi=(lh);fi
if [[ ${R_only} == "y" ]];then echo "RH only "; hemi=(rh);fi
echo ${hemi[*]}


SUBJECTS_DIR=`pwd`

 mkdir -p ${subj}/label
 mkdir -p ${subj}/mri/cort_labels
cd ${subj}/mri/


#### set up the volumetric labels 
for lado in "${side[@]}";do
	##### lado means side in spanish. sorry, lack of creativity

echo "######################################################"
fslmaths wm_${lado}.nii.gz -mas sub_cort.nii.gz cort_labels/subc_${lado}
echo "######################################################"
fslmaths wm_${lado}.nii.gz -sub cort_labels/subc_${lado} -bin cort_labels/wm_${lado}_cort
echo "######################################################"
fslmaths cort_labels/wm_${lado}_cort -dilM -dilM -dilM -fillh cort_labels/wm_${lado}_cort_dil #### dilate the label to remove spotting of mask
fslmaths cort_labels/wm_${lado}_cort_dil -mas cort_labels/subc_${lado} cort_labels/temp
fslmaths cort_labels/temp -mul 1 -bin cort_labels/temp

fslmaths cort_labels/wm_${lado}_cort_dil -sub cort_labels/temp  cort_labels/wm_${lado}_cort_dil

if [[ ${lado} == "left" ]];then
# 	echo fslmaths cort_labels/wm_${lado}_cort_dil -mul 2  cort_labels/wm_${lado}_cort_dil
# 	fslmaths cort_labels/wm_${lado}_cort_dil -mul 2  cort_labels/wm_${lado}_cort_dil

# else
	echo fslmaths cort_labels/wm_${lado}_cort_dil -mul 1  cort_labels/wm_${lado}_cort_dil

	fslmaths cort_labels/wm_${lado}_cort_dil -mul 1  cort_labels/wm_${lado}_cort_dil
fi

done

# # ## now the right side

# fslmaths wm_right.nii.gz -mas sub_cort.nii.gz cort_labels/subc_right
# fslmaths wm_right.nii.gz -sub cort_labels/subc_right -bin cort_labels/wm_right_cort
# fslmaths cort_labels/wm_right_cort -dilM -dilM cort_labels/wm_right_cort_dil

#gen whole brain wm labels
echo "#### creating volumes #######"

if [[ "${#side[@]}" -eq 2 ]];then 
	fslmaths cort_labels/wm_left_cort_dil -add cort_labels/wm_right_cort_dil cort_labels/wm_labels
else
	if [[ "${side[@]}" == "left" ]];then
		fslmaths cort_labels/wm_left_cort_dil -mul 0 cort_labels/wm_right_cort_dil
		fslmaths cort_labels/wm_left_cort_dil -add cort_labels/wm_right_cort_dil cort_labels/wm_labels
	fi

	if [[ "${side[@]}" == "right" ]];then
		fslmaths cort_labels/wm_right_cort_dil -mul 0 cort_labels/wm_left_cort_dil
		fslmaths cort_labels/wm_left_cort_dil -add cort_labels/wm_right_cort_dil cort_labels/wm_labels
	fi
fi

###time to convert these volumes to surface labels
echo "volumes created. converting to surfae labels"
## left first
cd cort_labels/

	echo mri_convert wm_labels.nii.gz wm_labels.mgz
	pwd
	mri_convert wm_labels.nii.gz wm_labels.mgz
	pwd
	

################### hemi 

for hem in "${hemi[@]}";do
	### fresh start 
	mri_convert wm_labels.nii.gz wm_labels.mgz
	id=1
	#### get identifier value
	# if [[ hem == "rh " ]];then 
	# 	id=1
	# else
	# 	id=1
	# fi
	#### create the surfacelabels
	mri_vol2label --i wm_labels.mgz  --id ${id} --v wm_labels.mgz --l ${hem}.cort.label
	# echo ""
	# pwd
	mri_label2vol --label ${hem}.cort.label --temp ../brain.mgz  --o ${hem}.cort_vol.mgz --identity

	echo "#### Generating Final Labels ####"
	mri_vol2surf --mov ${hem}.cort_vol.mgz  --ref brain.mgz --hemi ${hem} --o ${hem}.cort_srf.mgh --regheader ${subj}

	mri_vol2label --i ${hem}.cort_srf.mgh --id ${id} --surf ${subj}  ${hem} --l ../../label/${hem}.cortex

done























