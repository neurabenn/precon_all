#!/bin/bash
pwd

Usage() {
    echo " "
    echo "Preclinical Surface Reconstruction"
    echo ""
    echo "Usage: `basename $0` [options] -i <T1.nii.gz> -r <processes to run>"
    echo ""
    echo "Compulsory Arguments "
    echo "-s <Subject directory>		: Directory containing preprocessed animal for surfac generation "
  
    echo "-r < precon_all>		: hemisphere designationof lh or rh of surfaces to generate" 
    echo ""
    echo "-a <animal model> must be should be the name of a folder in the $PCP_PATH/standards/directory. Ex. $PCP_PATH/standards/pig" 
    echo "Optional Arguments" 
    echo "-h     help "
    echo " "
    echo " The following steps are applied:\n 1: Brain extraction \n 2: Denoising using SANLM and CAT 12 \n 3: Segmentation (FSL FAST) \n 4: WM Filling and Tesselation"
    echo " "
    echo " precon_all reconstructs the cortical surface from a single whole body image. "
    echo " precon_1 Only performs brain extraction i.e step 1 "
    echo " precon_2 performs steps Denoising, Segmentation, WM fill and generates surfaces"
    echo " precon_3 performs only WM filling and Generates surfaces "
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
help=""

while getopts ":i:r:a:h" opt ; do 
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
if [ "${img: -4}" == ".nii" ] || [ "${img: -7}" == ".nii.gz" ] ;then : ; else Usage; exit 1 ;fi ### check format of image is nifti
# echo "img"

# echo ${steps}
name=$(basename ${img})
dir=$(dirname $img) 

img=$(echo $(cd $(dirname "$img") && pwd -P)/$(basename "$img"))
dir=$(dirname ${img})/
brain_dir=${dir}${name/.nii.gz/}
# echo $img
# echo ${dir}


#### determine that the call matches the predefined options
if [ ${steps} == "precon_all" ] || [ ${steps} == "precon_1" ] || [ ${steps} == "precon_2" ] || [ ${steps} == "precon_3" ];then echo "${GREEN}performing ${steps} on ${img}${NC}"
else 
	echo "${RED} Please use one of the following predefined options as the -r argument "\n" precon_all "\n" precon_1 "\n" precon_2 precon_3${NC} "
	Usage
	exit 1 
fi

if [ ! -d $PCP_PATH/standards/${animal} ];then "Please specify or create an animal directory in $PCP_PATH/standards";Usage;exit 1 ;fi

######## conditions for precon all
if [ ${steps} == "precon_all" ];then 


####insert a check for directories to see if the subject has already been processed. if already processed don't run, or alternately delete inital outputs and rerun. #####

# echo ${PCP_PATH}bin/bet_pig.sh -i ${img} -o ${name/.nii.gz/}_brain
echo "this is right. your on the surf_repo. have fun editing."

mkdir -p ${dir}${name/.nii.gz/}
brain_dir=${dir}${name/.nii.gz/}

echo ${PCP_PATH}/bin/bet_animal.sh -i ${img} -o ${brain_dir} -a ${animal} -d y


 ${PCP_PATH}/bin/bet_animal.sh -i ${img} -o ${brain_dir} -a ${animal} -d y
echo " "
echo "extraction already run. now play with the rest"

##### parse outputs of brain extraction. Save warps. and convert. 
##### make mri directory here and mri/transforms
##### convert ants linear transforms to lta's and fsl transforms
# ##### move warps to transforms folder as well later for filling as well
cd ${brain_dir}

pwd

brain=$(basename ${brain_dir})_brain.nii.gz
mask=${brain/.nii.gz/_mask.nii.gz}
ls ${brain_dir}
## prepare brain image for segmentation. Denoise and N4 bias correction.
 ${ANTSPATH}DenoiseImage -d 3 -i ${brain} -o sanlm_${brain} -v 1


echo ${PCP_PATH}/bin/N4_pig.sh -i sanlm_${brain} -x ${mask}
${ANTSPATH}N4BiasFieldCorrection -d 3 -i sanlm_${brain}   -c [100x100x100x100,0.0000000001] -b [200] -o sanlm_${brain/.nii.gz/_0N4.nii.gz}  --verbose 0 

${PCP_PATH}/bin/seg_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -p $PCP_PATH/standards/${animal}/seg_priors -a ${animal}

#### conform outputs to isometric space.


# #### concatenate original affine (flirt format) transform with an applyisoxfm 0.8 / native resolution
# #### alternately add script to check for isometric. if not resample to largest value.
# ### get all paths ready for fill stage

echo "time to fill add isometric resampling in this step"
echo  ${PCP_PATH}/bin/fill_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -a ${animal}
${PCP_PATH}/bin/fill_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -a ${animal}

###proceed as normal. 


cd ${dir}
pwd
echo ${PCP_PATH}bin/tess_pig.sh -s ${ruta}  -h lh #-n 5 
 for hemi in lh rh;do
 
 ### potentially change file to work as function.  
  ${PCP_PATH}/bin/tess_pig.sh -s ${brain_dir}  -h ${hemi}  -a 5
 done
 fi

# ############# precon 1 conditions 

if [ ${steps} == "precon_1" ];then 
cp ${img} ${img/.nii.gz/orig.nii.gz}  
# echo ${PCP_PATH}bin/bet_pig.sh -i ${img} -o ${name/.nii.gz/}_brain
 ${PCP_PATH}bin/bet_animal.sh -i ${img} -o ${name/.nii.gz/}_brain

 brain_dir=${dir}${name/.nii.gz/}_brain

 echo ${brain_dir}

fi


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

### prepare brain image for segmentation. Denoise and N4 bias correction.
${ANTSPATH}DenoiseImage -d 3 -i ${brain} -o sanlm_${brain} 


echo ${PCP_PATH}/bin/N4_pig.sh -i sanlm_${brain} -x ${mask}
${ANTSPATH}N4BiasFieldCorrection -d 3 -i sanlm_${brain}   -c [100x100x100x100,0.0000000001] -b [200] -o sanlm_${brain/.nii.gz/_0N4.nii.gz}  --verbose 0 


${PCP_PATH}/bin/seg_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -p $PCP_PATH/standards/${animal}/seg_priors -a ${animal}

# #### conform outputs to isometric space.


# #### concatenate original affine (flirt format) transform with an applyisoxfm 0.8 / native resolution
# #### alternately add script to check for isometric. if not resample to largest value.
# ### get all paths ready for fill stage

echo "time to fill add isometric resampling in this step"
echo  ${PCP_PATH}/bin/fill_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -a ${animal}
${PCP_PATH}/bin/fill_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -a ${animal}

# ####proceed as normal. 


cd ${dir}
echo ${PCP_PATH}bin/tess_pig.sh -s ${ruta}  -h lh #-n 5 
 for hemi in lh rh;do

 ### potentially change file to work as function.  
 ${PCP_PATH}/bin/tess_pig.sh -s ${brain_dir}  -h ${hemi}  -a 5
done
##### precon3 parameters. still need to add control checks to check for segmentation files. 
fi





if [ ${steps} == "precon_3" ];then


echo "segmentation already run. now play with the rest"

# ##### parse outputs of brain extraction. Save warps. and convert. 
# ##### make mri directory here and mri/transforms
# ##### convert ants linear transforms to lta's and fsl transforms
# ##### move warps to transforms folder as well later for filling as well
cd ${brain_dir}

pwd

brain=$(basename ${brain_dir})_brain.nii.gz
mask=${brain/.nii.gz/_mask.nii.gz}



echo "time to fill add isometric resampling in this step"
echo  ${PCP_PATH}/bin/fill_pig.sh -i sanlm${brain/.nii.gz/_0N4.nii.gz} -a ${animal}
${PCP_PATH}/bin/fill_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} -a ${animal}

####proceed as normal. 


cd ${dir}
echo ${PCP_PATH}bin/tess_pig.sh -s ${ruta}  -h lh #-n 5 
 for hemi in lh rh;do

 ### potentially change file to work as function.  
 ${PCP_PATH}/bin/tess_pig.sh -s ${brain_dir}  -h ${hemi}  -a 5
 done
fi
