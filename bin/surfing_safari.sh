#!/bin/bash


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
    echo "Example:  `basename $0` -i <T1.nii.gz> -r precon_all "
    
    exit 1
}


NC=$(echo -en '\033[0m') #NC
RED=$(echo -en '\033[00;31m') #Red for error messages
GREEN=$(echo -en '\033[00;32m')
#### variables to be set by case statement
img=""
steps=""
help=""

while getopts ":i:r:h" opt ; do 
	case $opt in
		i) i=1;
			img=`echo $OPTARG`
			
				;;
		r) r=1;
			steps=`echo $OPTARG`
			
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
# echo $img
# echo ${dir}


#### determine that the call matvches the predefined options
if [ ${steps} == "precon_all" ] || [ ${steps} == "precon_1" ] || [ ${steps} == "precon_2" ] || [ ${steps} == "precon_3" ];then echo "${GREEN}performing ${steps} on ${img}${NC}"
else 
	echo "${RED} Please use one of the following predefined options as the -r argument\n precon_all \n precon_1 \n precon_2 precon_3${NC} "
	Usage
	exit 1 
fi



######## conditions for precon all
if [ ${steps} == "precon_all" ];then 

# echo ${PCP_PATH}bin/bet_pig.sh -i ${img} -o ${name/.nii.gz/}_brain
 ${PCP_PATH}bin/bet_pig.sh -i ${img} -o ${name/.nii.gz/}_brain

 brain_dir=${dir}${name/.nii.gz/}_brain

 # echo ${brain_dir}
 cd ${brain_dir}

  brain=${name/.nii.gz/}_brain.nii.gz
  mask=${name/.nii.gz/}_brain_mask.nii.gz

  # echo ${brain}
  # echo ${mask}
${PCP_PATH}bin/denoise.sh -i ${brain}


${PCP_PATH}bin/N4_pig.sh -i sanlm_${brain} -x ${mask}

${PCP_PATH}bin/seg_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz}

${PCP_PATH}bin/fill_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} 


cd ${dir}
echo ${PCP_PATH}bin/tess_pig.sh -s ${ruta}  -h lh #-n 5 
 for hemi in lh rh;do 
 	${PCP_PATH}bin/tess_pig.sh -s ${brain_dir}  -h ${hemi}  -a 5
 done
fi

############# precon 1 conditions 

if [ ${steps} == "precon_1" ];then 

# echo ${PCP_PATH}bin/bet_pig.sh -i ${img} -o ${name/.nii.gz/}_brain
 ${PCP_PATH}bin/bet_pig.sh -i ${img} -o ${name/.nii.gz/}_brain

 brain_dir=${dir}${name/.nii.gz/}_brain
fi


########## precon 2 steps ########### 

if [ ${steps} == "precon_2" ];then 

 brain_dir=${dir}${name/.nii.gz/}_brain
echo ${brain_dir}
 if [ -d ${brain_dir} ];then :; else " ${RED}A folder of the subject name appended with _brain is required to go forward in processing ${NC}";Usage; exit 1 ;fi 


 # echo ${brain_dir}
 cd ${brain_dir}

  brain=${name/.nii.gz/}_brain.nii.gz
  mask=${name/.nii.gz/}_brain_mask.nii.gz

  # echo ${brain}
  # echo ${mask}
${PCP_PATH}bin/denoise.sh -i ${brain}


${PCP_PATH}bin/N4_pig.sh -i sanlm_${brain} -x ${mask}


${PCP_PATH}bin/seg_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz}

${PCP_PATH}bin/fill_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} 


cd ${dir}

 for hemi in lh rh;do 
 	${PCP_PATH}bin/tess_pig.sh -s ${brain_dir}  -h ${hemi}  -a 5
 done
fi
##### precon3 parameters. still need to add control checks to check for segmentation files. 
if [ ${steps} == "precon_3" ];then
	 brain_dir=${dir}${name/.nii.gz/}_brain/
	brain=${name/.nii.gz/}_brain.nii.gz
	cd ${brain_dir}

	${PCP_PATH}bin/fill_pig.sh -i sanlm_${brain/.nii.gz/_0N4.nii.gz} 
	cd ${dir}
 	echo ${PCP_PATH}bin/tess_pig.sh -s ${ruta}  -h lh #-n 5 
 for hemi in lh rh;do 
 	 ${PCP_PATH}bin/tess_pig.sh -s ${brain_dir}  -h ${hemi}  -a 5
 done
fi


