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

#### get hemisphere of interest if defined. 
#### also creates a temporary file of the opposite hemisphere used to trick mris_volmask
hemi=(lh rh)
if [[ ${L_only} == "y" ]];then echo "LH only"; hemi=(lh); fill=rh;fi
if [[ ${R_only} == "y" ]];then echo "RH only "; hemi=(rh); fill=lh;fi
echo ${hemi[*]}


SUBJECTS_DIR=`pwd`
outer_dir=`pwd`

 mkdir -p ${subj}/label
 mkdir -p ${subj}/mri/cort_labels

flip_handedness_orient() {
  local orient="$1"
  case "${orient:0:1}" in
    R) echo "L${orient:1}" ;;
    L) echo "R${orient:1}" ;;
    *) echo "Cannot flip handedness for orientation: ${orient}" >&2; return 1 ;;
  esac
}

brain_mgz="${subj}/mri/brain.mgz"
det=$(mri_info "${brain_mgz}" | awk '/voxel-to-ras determinant/ {print $3}')
native_orient=$(mri_info "${brain_mgz}" | awk -F': ' '/Orientation/ {print $2}')
work_orient="${native_orient}"
needs_flip=0

if awk "BEGIN {exit !(${det} > 0)}"; then
  needs_flip=1
  work_orient=$(flip_handedness_orient "${native_orient}") || exit 1
  echo "Determinant positive (${det}), flipping handedness from ${native_orient} to ${work_orient}  "
else
  echo "Determinant negative (${det}), no handedness flip needed"
fi


cd ${subj}

if [ "$needs_flip" -eq 1 ]; then
  mri_convert mri/brain.mgz mri/aseg.mgz --out_orientation "${work_orient}"
else
  mri_convert mri/brain.mgz mri/aseg.mgz --out_orientation "${native_orient}"
fi

#### set up the volumetric labels 

len=`echo "${#side[@]}"`
### check if doing both hemispheres
if [[ ${len} -lt 2 ]];then 
	echo "doing ${lado} only"
	#create the dummy surfaces for volmask
	cp surf/${hemi}.white surf/${fill}.white
	cp surf/${hemi}.pial surf/${fill}.pial
	echo "#############################"
	### run volmask 
	mris_volmask --save_ribbon ${subj}
	### remove dummies
	rm surf/${fill}.white 
	rm surf/${fill}.pial 
	### prep the volume to be converted to the cortex and subcortex label
	mri_convert mri/ribbon.mgz mri/ribbon.nii.gz 
	fslmaths mri/ribbon.nii.gz  -bin -sub mri/sub_cort.nii.gz -bin  mri/${hemi}.ribbon.nii.gz 
else
	echo "doing both"
	mris_volmask --save_ribbon ${subj}
	echo ${hemi[*]}

	mri_convert mri/ribbon.mgz mri/ribbon.nii.gz --out_orientation "${native_orient}"

	fslmaths mri/ribbon.nii.gz -mas mri/sub_cort.nii.gz tmp_subc.nii.gz 
	fslmaths mri/ribbon.nii.gz -sub tmp_subc.nii.gz  mri/ribbon.nii.gz -odt int
	fslmaths mri/ribbon.nii.gz -uthr 21 -bin  mri/${hemi[0]}.ribbon.nii.gz 
	fslmaths mri/ribbon.nii.gz -thr 21 -bin   mri/${hemi[1]}.ribbon.nii.gz 
	rm tmp_subc.nii.gz 
fi

#### go into the mri directory to get the ribbons ready for label gen
cd mri/
#### now do the cortex label generation from the ribbon masks  
for i  in `ls ?h.ribbon.nii.gz`;do 
	hem=${i/.ribbon.nii.gz}
	mri_vol2label --i   ${hem}.ribbon.nii.gz --id 1 --v ${hem}.ribbon.nii.gz  --l ${hem}.cort.label
	mri_label2vol --label ${hem}.cort.label --temp brain.mgz  --o ${hem}.cort_vol.mgz --identity
	mri_vol2surf --mov ${hem}.cort_vol.mgz  --ref brain.mgz --hemi ${hem} --o ${hem}.cort_srf.mgh --regheader ${subj}
	mri_vol2label --i ${hem}.cort_srf.mgh --id 1  --surf ${subj}  ${hem}  --l ../label/${hem}.cortex
	mri_vol2label --i ${hem}.cort_srf.mgh --id 0  --surf ${subj}  ${hem}  --l ../label/${hem}.subcortex
done

### finally make an annotation of cortex and non cortex. 
### this can help improve mris_registration down stream. 
### allows registration to zero out medial wall instead of including it
cd ../label 
ln -s lh.subcortex.label lh.Unknown.label
ln -s rh.subcortex.label rh.Unknown.label

cd ${outer_dir}
mris_label2annot --s ${subj} --h lh --ctab $PCP_PATH/standards/cort.annot.ctab --l ${subj}/label/lh.Unknown.label --l ${subj}/label/lh.cortex.label --surf white --a Cortex
mris_label2annot --s ${subj} --h rh --ctab $PCP_PATH/standards/cort.annot.ctab --l ${subj}/label/rh.Unknown.label --l ${subj}/label/rh.cortex.label --surf white --a Cortex