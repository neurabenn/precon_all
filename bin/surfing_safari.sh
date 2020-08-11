#!/bin/bash
Usage() {
    echo " "
    echo "Preclinical Surface Reconstruction"
    echo ""
    echo "Usage: `basename $0` [options] -i <T1.nii.gz> -r <processes to run>"
    echo ""
    echo "Compulsory Arguments "
    echo "-i <T1 image>		: Directory containing preprocessed animal for surfac generation "
  
    echo "-r < precon_all>		: hemisphere designationof lh or rh of surfaces to generate" 
    echo ""
    echo "-a <animal model> must be should be the name of a folder in the $PCP_PATH/standards/directory. Ex. $PCP_PATH/standards/pig" 
    echo "-n no brain extraction. Using a previously extracted brain. only runs linear transforms. " 
    echo "-v down sample individual surfaces to a given resolution in HCP space. " 
    echo " -t < Segmentation threshold default is 0.5 >"
    echo " -s < Segment with ANTs AtroposN4 instead of FAST threshold default is 0.1 >"
    echo " -L  Left Hemisphere only"
    echo " -R  Right Hemisphere only"
    echo "Optional Arguments" 
    echo "-h     help "
    echo " "
    echo " The following steps are applied:\n 1: Brain extraction \n 2: Denoising using SANLM and in ANTs \n 3: Segmentation (FSL FAST) \n 4: WM Filling and Tesselation"
    echo " "
    echo " precon_all reconstructs the cortical surface from a single whole body image. "
    echo " precon_1 Only performs brain extraction i.e step 1 "
    echo " precon_2 performs steps Denoising, Segmentation, WM fill and generates surfaces"
    echo " precon_3 performs only WM filling and Generates surfaces "
    echo " precon_art meant for art projects or figures in which the non_cort mask is included. Only run after precon_2"
    echo " precon art is not meant to actually  give any statistics or information on the surface. visualization purposes only "
    echo ""
    echo "Example:  `basename $0` -i <T1.nii.gz> -r precon_all -a <pig>"
    
    exit 1
}


NC=$(echo -en '\033[0m') #NC
RED=$(echo -en '\033[00;31m') #Red for error messages
GREEN=$(echo -en '\033[00;32m')
#### variables to be set by case statement
img=""
steps=""
animal=""
verts=""
no_extract=""
ants_seg=""
L_only=""
R_only=""
help=""

while getopts ":i:r:a:t:v:nsLRh" opt ; do 
    
	case $opt in
		i) i=1;
			img=`echo $OPTARG`
			
				;;
		r) r=1;
			steps=`echo $OPTARG`

			
			;;
    a) a=1;
      animal=`echo $OPTARG`
      ;;
		h) h=1;
			steps=`echo $OPTARG`
			if [ ${h} -lt 1 ];then : ; else: echo " ${RED} insert help text here ${NC}"; exit 1;fi #### work on this later. not top priority this minute
			;;
    t)  
        thresh=`echo $OPTARG`
            ;;	
    v)  
            verts=`echo $OPTARG`
                ;;
     n)  n=1;
          no_extract="y"
                ;;
    s)
          ants_seg="y"
                ;;
    L)
          L_only="y"
                ;;
    R)
          R_only="y"
                ;;
		\?)
		  echo "Invalid option:  -$OPTARG" 

		  	Usage
		  	exit 1
		  	;;

	esac 
done

#### check inputs are valid#########
if [[ ${h} -eq 1 ]];then echo "${RED}\n INSERT HELP STATEMENT ${NC}" ; Usage; exit 1 ;fi
if [[ ${i} -lt 1 ]];then echo "${RED}\n-i is a compulsory Argument${NC}" ; Usage; exit 1 ;fi
if [[ ${r} -lt 1 ]];then echo "${RED}\n-r is a compulsory Argument${NC}" ; Usage; exit 1 ;fi
if [ ! -f ${img} ];then echo " "; echo " ${RED}CHECK INPUT FILE PATH ${NC}"; Usage; exit 1;fi ### check input file exists


################################### CHANGE TO ALSO CHECK FOR BEDPOSTX FIRECTORY FILES IN THE EVENT FAKE T1 BEING USED #####################

if [ "${img: -4}" == ".nii" ] || [ "${img: -7}" == ".nii.gz" ] ;then : ; else Usage; exit 1 ;fi ### check format of image is nifti


###### default thresholiding of partial volume estimates. 
###### recommended 0.5 for FASt and 0.1 for ANTs
if [[ ${thresh} == "" ]] && [[ ${ants_seg} == "y" ]];then 
	#### ants threshold
    thresh=0.1
else
	#### FSL threshold
	if [[ ${thresh} == "" ]];then
		thresh=0.5
	fi
 :
fi

if [[ ${verts} == "" ]];then
    echo "no vertices specified"
    echo "native output will not be resampled"
else
    echo "native surfaces will be downsampled to ${verts}"
fi



side=(lh rh)
if [[ ${L_only} == "y" ]];then echo "Left only"; side=(lh);fi
if [[ ${R_only} == "y" ]];then echo "Right only"; side=(rh);fi
echo ${side[*]}

# echo ${steps}
name=$(basename ${img})
dir=$(dirname $img) 

img=$(echo $(cd $(dirname "$img") && pwd -P)/$(basename "$img"))
dir=$(dirname ${img})/
brain_dir=${dir}${name/.nii.gz/}
# echo $img
# echo ${dir}


##### add a source of freesurfer. this should help with final steps in generating cortical labels and volmask. 
source $FREESURFER_HOME/SetUpFreeSurfer.sh
#### determine that the call matches the predefined options
if [ ${steps} == "precon_all" ] || [ ${steps} == "precon_1" ] || [ ${steps} == "precon_2" ] || [ ${steps} == "precon_3" ] || [ ${steps} == "precon_4" ] || [ ${steps} == "precon_art" ];then echo "${GREEN}performing ${steps} on ${img}${NC}"
else 
	echo "${RED} Please use one of the following predefined options as the -r argument "\n" precon_all "\n" precon_1 "\n" precon_2 precon_3${NC} "
	Usage
	exit 1 
fi

######################### CHECK IF BEDPOST DIERCTORY IS INPUT. IF SO CREATE FAKE T1 AND USE FAKE T1 FOR REST OF PIPELINE########################
###################4###### CONVERT T2 TO T1 LATER ON. DO SEGMENTATION IN NATIVE MODLAITY BETWEEN T2 AND T1 #####################################


### check to see if brain is already extracted. if so than set up required directory structure. 
if [[  ${no_extract} == "y"  ]];then
        echo "USING PRE_EXTRACTED BRAIN"
        mkdir -p ${dir}${name/.nii.gz/}
    brain_dir=${dir}${name/.nii.gz/}
    #### apply brain masks
    cd ${brain_dir}
    
    brain=$(basename ${brain_dir})_brain.nii.gz
    mask=${brain/.nii.gz/_mask.nii.gz}


    $FSLDIR/bin/fslmaths ${img}  ${brain}
    $FSLDIR/bin/fslmaths ${brain} -thr 0 -bin ${mask}
    mkdir -p ${brain_dir}/mri/transforms
     
    if [ ${steps} == "precon_all" ];then 
        steps=precon_2
    fi

fi

#### check to see if using single subject masks. this assumes the brain is ex-vivo or pre_extracted. 
if [ ${animal} == "masks" ];then

echo "Using supplied masks for a single subject."


mkdir -p ${dir}${name/.nii.gz/}
brain_dir=${dir}${name/.nii.gz/}
cp ${img}  ${brain_dir}/
cp -r ${dir}/masks ${brain_dir}/masks
#### apply brain masks
cd ${brain_dir}

brain=$(basename ${brain_dir})_brain.nii.gz
mask=${brain/.nii.gz/_mask.nii.gz}

$FSLDIR/bin/fslmaths ${img} -mas ${brain_dir}/masks/brain_mask.nii.gz ${brain}
$FSLDIR/bin/imcp ${brain_dir}/masks/brain_mask.nii.gz ${mask}
mkdir -p ${brain_dir}/mri/transforms

if [ ${steps} == "precon_all" ];then 
    steps=precon_2
fi

fi


###############precon_all code block
######## conditions for precon all
if [ ${steps} == "precon_all" ];then 


####insert a check for directories to see if the subject has already been processed. if already processed don't run, or alternately delete inital outputs and rerun. #####

# echo ${PCP_PATH}bin/bet_pig.sh -i ${img} -o ${name/.nii.gz/}_brain

mkdir -p ${dir}${name/.nii.gz/}
brain_dir=${dir}${name/.nii.gz/}

echo ${PCP_PATH}/bin/bet_animal.sh -i ${img} -o ${brain_dir} -a ${animal} -d y
##### check for a preliminary alignment matrix first prior to running. sometimes this is necessary for difficult brains. 
if [ -f ${dir}/pre_extract.mat ];then
    echo " this brain uses a prior linear registraton of pre_extract.mat as an initial starting point for brain extraction"
    ${PCP_PATH}/bin/bet_animal.sh -i ${img} -o ${brain_dir} -a ${animal} -d y -m  ${dir}/pre_extract.mat
else
    ${PCP_PATH}/bin/bet_animal.sh -i ${img} -o ${brain_dir} -a ${animal} -d y
fi

echo " "
echo "###### Already Extracted ########"

##### parse outputs of brain extraction. Save warps. and convert. 
##### make mri directory here and mri/transforms
##### convert ants linear transforms to lta's and fsl transforms
# ##### move warps to transforms folder as well later for filling as well
cd ${brain_dir}

pwd

brain=$(basename ${brain_dir})_brain.nii.gz
mask=${brain/.nii.gz/_mask.nii.gz}
ls ${brain_dir}




echo "##### DEBUGGING  inserting ants compatibilty"
# prepare brain image for segmentation. Denoise and N4 bias correction.
 ${ANTSPATH}/DenoiseImage -d 3 -i ${brain} -o sanlm_${brain} -v 1


echo ${PCP_PATH}/bin/N4_pig.sh -i sanlm_${brain} -x ${mask}
${ANTSPATH}/N4BiasFieldCorrection -d 3 -i sanlm_${brain}   -c [100x100x100x100,0.0000000001] -b [200] -o sanlm_${brain/.nii.gz/_0N4.nii.gz}  --verbose 0 

if [ -d $PCP_PATH/standards/${animal}/seg_priors ];then

    echo " USING SEGMENTATION PRIORS "
    if [[  ${ants_seg} == "y"  ]];then
    	echo "Using ANTs Atropos"
    	${PCP_PATH}/bin/seg_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -p $PCP_PATH/standards/${animal}/seg_priors -a ${animal} -t ${thresh} -s

    else
    	echo "Using FSL FAST "
		${PCP_PATH}/bin/seg_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -p $PCP_PATH/standards/${animal}/seg_priors -a ${animal} -t ${thresh}
	fi
	else
	echo " NO SEGMENTATION PRIORS "
	if [[  ${ants_seg} == "y"  ]];then 
		echo "Using Ants Atropos"
		${PCP_PATH}/bin/seg_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -a ${animal} -t ${thresh} -s 
	else
		echo "Using FSL FAST"
    	
    	${PCP_PATH}/bin/seg_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -a ${animal} -t ${thresh}
    fi
fi

cd ${brain_dir}

pwd

brain=$(basename ${brain_dir})_brain.nii.gz
mask=${brain/.nii.gz/_mask.nii.gz}


if [[ ${L_only} == "y" ]];then 
    echo "only filling left"
    ${PCP_PATH}/bin/fill_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -a ${animal} -L
fi

if [[ ${R_only} == "y" ]];then
    echo "only filling right" 
    ${PCP_PATH}/bin/fill_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -a ${animal} -R
fi
echo ##### third option 

if [[ ${R_only} == "" ]] && [[ ${L_only} == "" ]];then
   
    ${PCP_PATH}/bin/fill_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -a ${animal}
fi

##### lets build the surfaces now
cd ${dir}


 for hemi in "${side[@]}";do
 ### potentially change file to work as function.  
 ${PCP_PATH}/bin/tess_pig.sh -s ${brain_dir}  -h ${hemi}  -a 5
 done

SUBJECTS_DIR=${dir}
echo $SUBJECTS_DIR
echo ${brain_dir}
subj=$(basename ${brain_dir})
# # ### generate cortex label from masks 
cd $SUBJECTS_DIR
pwd

if [[ ${L_only} == "y" ]];then 
    echo "only making left labels"
echo "${PCP_PATH}bin/cortex_labelgen.sh -s ${subj} -L" |bash
fi

if [[ ${R_only} == "y" ]];then 
    echo "only making right labels"
echo "${PCP_PATH}bin/cortex_labelgen.sh -s ${subj} -R" |bash
fi

if [[ ${R_only} == "" ]] && [[ ${L_only} == "" ]];then
    echo "only making left and right labels"
echo "${PCP_PATH}bin/cortex_labelgen.sh -s ${subj} " |bash
fi

# # # #### create a fake aseg to get the ribbon 
cp ${subj}/mri/brain.mgz ${subj}/mri/aseg.mgz 
# # # # ### generate the FS ribbon mask
if [[ ${R_only} == "" ]] && [[ ${L_only} == "" ]];then
    mris_volmask --save_ribbon $(basename ${brain_dir})
fi


#### check for downsampling, and if specified resample to nearest icosahedron
if [[ "$verts" != "" ]];then 
    #### down sample if vertices have been specified
    for hemi in "${side[@]}";do
        echo "downsaplig mesh to icosahedron nearest ${verts} "
        $PCP_PATH/bin/down_surf.sh -s ${brain_dir} -h ${hemi} -v ${verts}
    done
fi

fi


##########################################################################################################################################
##########################################################################################################################################
##########################################################################################################################################
##########################################################################################################################################
# ############# precon 1 conditions 

if [ ${steps} == "precon_1" ];then 
    

mkdir -p ${dir}${name/.nii.gz/}
brain_dir=${dir}${name/.nii.gz/}



echo ${PCP_PATH}/bin/bet_animal.sh -i ${img} -o ${brain_dir} -a ${animal} -d y
##### check for a preliminary alignment matrix first prior to running. sometimes this is necessary for difficult brains. 
    if [ -f ${dir}/pre_extract.mat ];then
        echo " this brain uses a prior linear registraton of pre_extract.mat as an initial starting point for brain extraction"
        ${PCP_PATH}/bin/bet_animal.sh -i ${img} -o ${brain_dir} -a ${animal} -d y -m  ${dir}/pre_extract.mat
    else
        ${PCP_PATH}/bin/bet_animal.sh -i ${img} -o ${brain_dir} -a ${animal} -d y
    fi
fi

echo " "
echo "extraction run."

##########################################################################################################################################
##########################################################################################################################################
##########################################################################################################################################
##########################################################################################################################################
# ########## precon 2 steps ########### 

if [ ${steps} == "precon_2" ];then 
echo "extraction already run. now play with the rest"

# ##### parse outputs of brain extraction. Save warps. and convert. 
# ##### make mri directory here and mri/transforms
# ##### convert ants linear transforms to lta's and fsl transforms
# ##### move warps to transforms folder as well later for filling as well
cd ${brain_dir}

pwd

brain=$(basename ${brain_dir})_brain.nii.gz
mask=${brain/.nii.gz/_mask.nii.gz}

# prepare brain image for segmentation. Denoise and N4 bias correction.

echo "##### DEBUGGING  inserting ants compatibilty"
# prepare brain image for segmentation. Denoise and N4 bias correction.
 ${ANTSPATH}/DenoiseImage -d 3 -i ${brain} -o sanlm_${brain} -v 1


echo ${PCP_PATH}/bin/N4_pig.sh -i sanlm_${brain} -x ${mask}
${ANTSPATH}/N4BiasFieldCorrection -d 3 -i sanlm_${brain}   -c [100x100x100x100,0.0000000001] -b [200] -o sanlm_${brain/.nii.gz/_0N4.nii.gz}  --verbose 0 

if [ -d $PCP_PATH/standards/${animal}/seg_priors ];then

    echo " USING SEGMENTATION PRIORS "
    if [[  ${ants_seg} == "y"  ]];then
    	echo "Using ANTs Atropos"
    	${PCP_PATH}/bin/seg_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -p $PCP_PATH/standards/${animal}/seg_priors -a ${animal} -t ${thresh} -s

    else
    	echo "Using FSL FAST "
		${PCP_PATH}/bin/seg_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -p $PCP_PATH/standards/${animal}/seg_priors -a ${animal} -t ${thresh}
	fi
	else
	echo " NO SEGMENTATION PRIORS "
	if [[  ${ants_seg} == "y"  ]];then 
		echo "Using Ants Atropos"
		${PCP_PATH}/bin/seg_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -a ${animal} -t ${thresh} -s 
	else
		echo "Using FSL FAST"
    	
    	${PCP_PATH}/bin/seg_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -a ${animal} -t ${thresh}
    fi
fi
echo "debugging"

### conform outputs to isometric space.


### concatenate original affine (flirt format) transform with an applyisoxfm 0.8 / native resolution
### alternately add script to check for isometric. if not resample to largest value.
## get all paths ready for fill stage

cd ${brain_dir}

pwd

brain=$(basename ${brain_dir})_brain.nii.gz
mask=${brain/.nii.gz/_mask.nii.gz}


if [[ ${L_only} == "y" ]];then 
    echo "only filling left"
    ${PCP_PATH}/bin/fill_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -a ${animal} -L
fi

if [[ ${R_only} == "y" ]];then
    echo "only filling right" 
    ${PCP_PATH}/bin/fill_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -a ${animal} -R
fi
echo ##### third option 

if [[ ${R_only} == "" ]] && [[ ${L_only} == "" ]];then
   
    ${PCP_PATH}/bin/fill_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -a ${animal}
fi

##### lets build the surfaces now
cd ${dir}


 for hemi in "${side[@]}";do
 ### potentially change file to work as function.  
 ${PCP_PATH}/bin/tess_pig.sh -s ${brain_dir}  -h ${hemi}  -a 5
 done

SUBJECTS_DIR=${dir}
echo $SUBJECTS_DIR
echo ${brain_dir}
subj=$(basename ${brain_dir})
# # ### generate cortex label from masks 
cd $SUBJECTS_DIR
pwd

if [[ ${L_only} == "y" ]];then 
    echo "only making left labels"
echo "${PCP_PATH}bin/cortex_labelgen.sh -s ${subj} -L" |bash
fi

if [[ ${R_only} == "y" ]];then 
    echo "only making right labels"
echo "${PCP_PATH}bin/cortex_labelgen.sh -s ${subj} -R" |bash
fi

if [[ ${R_only} == "" ]] && [[ ${L_only} == "" ]];then
    echo "only making left and right labels"
echo "${PCP_PATH}bin/cortex_labelgen.sh -s ${subj} " |bash
fi

# # # #### create a fake aseg to get the ribbon 
cp ${subj}/mri/brain.mgz ${subj}/mri/aseg.mgz 
# # # # ### generate the FS ribbon mask
if [[ ${R_only} == "" ]] && [[ ${L_only} == "" ]];then
    mris_volmask --save_ribbon $(basename ${brain_dir})
fi


#### check for downsampling, and if specified resample to nearest icosahedron
if [[ "$verts" != "" ]];then 
    #### down sample if vertices have been specified
    for hemi in "${side[@]}";do
        echo "downsaplig mesh to icosahedron nearest ${verts} "
        $PCP_PATH/bin/down_surf.sh -s ${brain_dir} -h ${hemi} -v ${verts}
    done
fi



fi


##########################################################################################################################################
##########################################################################################################################################
##########################################################################################################################################
##########################################################################################################################################


if [ ${steps} == "precon_3" ];then


echo "segmentation already run."

# ##### parse outputs of brain extraction. Save warps. and convert. 
# ##### make mri directory here and mri/transforms
# ##### convert ants linear transforms to lta's and fsl transforms
# ##### move warps to transforms folder as well later for filling as well
cd ${brain_dir}

pwd

brain=$(basename ${brain_dir})_brain.nii.gz
mask=${brain/.nii.gz/_mask.nii.gz}


if [[ ${L_only} == "y" ]];then 
    echo "only filling left"
    ${PCP_PATH}/bin/fill_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -a ${animal} -L
fi

if [[ ${R_only} == "y" ]];then
    echo "only filling right" 
    ${PCP_PATH}/bin/fill_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -a ${animal} -R
fi
echo ##### third option 

if [[ ${R_only} == "" ]] && [[ ${L_only} == "" ]];then
   
    ${PCP_PATH}/bin/fill_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -a ${animal}
fi

#### lets build the surfaces now
cd ${dir}


 for hemi in "${side[@]}";do
 ### potentially change file to work as function.  
 ${PCP_PATH}/bin/tess_pig.sh -s ${brain_dir}  -h ${hemi}  -a 5
 done

SUBJECTS_DIR=${dir}
echo $SUBJECTS_DIR
echo ${brain_dir}
subj=$(basename ${brain_dir})
# # ### generate cortex label from masks 
cd $SUBJECTS_DIR
# pwd

if [[ ${L_only} == "y" ]];then 
    echo "only making left labels"
echo "${PCP_PATH}bin/cortex_labelgen.sh -s ${subj} -L" |bash
fi

if [[ ${R_only} == "y" ]];then 
    echo "only making right labels"
echo "${PCP_PATH}bin/cortex_labelgen.sh -s ${subj} -R" |bash
fi

if [[ ${R_only} == "" ]] && [[ ${L_only} == "" ]];then
    echo "making left and right labels"
echo "${PCP_PATH}bin/cortex_labelgen.sh -s ${subj} " |bash
fi
# # # #### create a fake aseg to get the ribbon 
cp ${subj}/mri/brain.mgz ${subj}/mri/aseg.mgz 
# # # # ### generate the FS ribbon mask
if [[ ${R_only} == "" ]] && [[ ${L_only} == "" ]];then
    mris_volmask --save_ribbon $(basename ${brain_dir})
fi

#### check for downsampling, and if specified resample to nearest icosahedron
if [[ "$verts" != "" ]];then 
    #### down sample if vertices have been specified
    for hemi in "${side[@]}";do
        echo "downsaplig mesh to icosahedron nearest ${verts} "
        $PCP_PATH/bin/down_surf.sh -s ${brain_dir} -h ${hemi} -v ${verts}
    done
fi

fi


if [ ${steps} == "precon_4" ];then
    echo "resampling native surfaces to lower resolution mesh"
    for hemi in "${side[@]}";do
        echo "downsaplig mesh to icosahedron nearest ${verts} "
        $PCP_PATH/bin/down_surf.sh -s ${brain_dir} -h ${hemi} -v ${verts}
    done
fi



if [ ${steps} == "precon_art" ];then
##### generatses stl files of white and pial surfaces
### also white and gray raw  of non cortical matter to add in for visualization

echo "Will include cerebellum and non cortical structures. meant for figures and art projects"

cd ${brain_dir}
$PCP_PATH/bin/art.sh
fi
