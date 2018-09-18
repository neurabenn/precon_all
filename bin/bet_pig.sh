#!/bin/bash 
Usage() {
    echo " "
    echo "Usage: `basename $0` [options] -i <T1_image> "
    echo ""
    echo " Compulsory Arguments "
    echo "-i <T1.nii.gz>                  :Compulsory input, Image must include nii or nii.gz file extension "
    echo " "
    echo " Optional Arguments" 
    echo " -p <prefix>  	                : Output prefix. Default output is T1_image_brain.  " 
    echo " -o <output_directory>          : Output directory. Default is directory of input image"
    echo " -d <y/n>                       : Enable or disbale denoising. Default is to denoise prior to brain extraction "
    echo " "
    echo "Example:  `basename $0` [options] -i pig_T1.nii.gz -p extract -o pig_brain_dir -d y  "
    echo " If using in conjunction with the Quadroped surface reconstruction pipeline follow the reccomended directory structure. \

    i.e. a single directory for each subject with the folder as the subject name."
    echo " "
    exit 1
}
NC=$(echo -en '\033[0m') #NC
RED=$(echo -en '\033[00;31m') #Red for error messages





if [ $# -lt 2 ] ; then Usage; exit 0; fi #### check that command is not called empty


####variable to be filled via options
img=""
prefix=""
out=""
denoise=""


#### define options for running script

while getopts ":i:p:o:d:" opt ; do 
	case $opt in
		i) 
			i=1;
			img=`echo $OPTARG`
			if [ ! -f ${img} ];then echo " "; echo "${RED}CHECK INPUT FILE PATH ${NC}"; Usage; exit 1;fi ### check input file exists
			if [ "${img: -4}" == ".nii" ] || [ "${img: -3}" == ".gz" ] ;then : ; else Usage; exit 1 ;fi
			;;
		p)
		
			prefix=`echo $OPTARG`
			;;
		o) >&2
			out=`echo $OPTARG`
			out=$(dirname $img)/${out}
			
			if [ -d ${out} ];then : ; else mkdir ${out} ;fi
				cp ${img} ${out}/
			;;
		d) >&2
			denoise=`echo $OPTARG`
			if [ "${denoise}" == "y" ] || [ "${denoise}" == "n" ] ;then : ; else Usage; exit 1 ;fi
			;;

		\?)
		  echo "Invalid option:  -$OPTARG" >&2

		  	Usage
		  	exit 1
		  	;;

	esac 
done

#### set default outputs if not flagged in the options
if [ ${i} -eq 1 ];then : ; else echo "${RED}-i is required input ${NC}" ; Usage; exit 2;fi

if [ "${prefix}" == "" ];then prefix="extract" ;fi #### default prefix of extracted file is extract
if [ "${out}" == "" ];then out=$(dirname $img) ;fi  ##### default output folder is the 
if [ "${denoise}" == "" ];then denoise="y" ;fi #### default is to denoise full body image prior to brain extraction

##########template and mask files for extraction ###########
######### future versions of this script will allow for customizable templates to be used int he brain extraction process. 
######### for now if you desire other species to have their brain extracted change each file accordingly
temp=${PCP_PATH}standards/extraction/pig_temp.nii.gz ########## whole body template image for registration
prob_mask=${PCP_PATH}standards/extraction/brain_mask.nii.gz ######probablistic extraction mask. If you don't have one you can make one via smoothing a prior brain extraction binary mask
reg_mask=${PCP_PATH}standards/extraction/reg_mask.nii.gz ######### full body registration mask

if [ "${denoise}" == "y" ];then

	if [[ ${CAT12_PATH} != "" ]];then
	cp ${PCP_PATH}/mat_files/denoise_temp.m ${out}/denoise_sanlm_body.m
	cd ${out}
	ruta=`pwd` ### define absolute pathto current directory

	T1=$(basename ${img})

	 if [ "${T1: -3}" == ".gz" ];then ##### prepare file for cat12 denoising
 	#echo "unzipping" ${T1}
 		gunzip ${T1}

 	 	T1=${T1/.gz/}
 	else
 		echo ${anat} "is alread unzipped. Ready for denoising. "
 	 	T1=${T1}
 	fi
 	sub=${ruta}/${T1}
  	 echo "denoising " $sub
   	sed -i -e  "s+'<UNDEFINED>'+{'${sub},1'}+g" denoise_sanlm_body.m 
   	################ denoising input image #################
   	sh ${CAT12_PATH}cat_batch_spm_fg.sh denoise_sanlm_body.m 
   else
   	echo "CAT12_PATH does not exist. Using Ants denoising algorithm"
   	${ANTSPATH}/DenoiseImage -d 3 -i ${img} -o sanlm_${img}
   fi

	###### prepare extraction variables ########### 
T1=sanlm_${T1}
#ruta=$(dirname $sub) 
pwd 

	 if [ "${T1: -4}" == ".nii" ];then 
 		echo "zipping" ${T1}
  		gzip ${T1}
  		T1=${T1}.gz
	 	echo $T1
	else
 		echo ${anat} "is alread zipped. Ready for extraction."
 		T1=${anat}
 	fi

 ###extract the brain. $ANTSPATH must be defined	
 ${ANTSPATH}antsBrainExtraction.sh -d 3 -a ${T1}  -e ${temp}  -m ${prob_mask} -o  ${prefix} -f $reg_mask

#rename output to ${file}_brain / ${file}_brain_mask
mv ${prefix}BrainExtractionBrain.nii.gz ${T1/.nii.gz/_brain.nii.gz}
brain=${T1/.nii.gz/_brain.nii.gz}
mv ${brain} ${brain/sanlm_/} 
mv ${prefix}BrainExtractionMask.nii.gz ${T1/.nii.gz/_brain_mask.nii.gz}
mask=${T1/.nii.gz/_brain_mask.nii.gz}
mv ${mask} ${mask/sanlm_/}
else
 cd ${out} 
 pwd
 T1=$(basename ${img})
 


	 if [ "${T1: -4}" == ".nii" ];then 
 		echo "zipping" ${T1}
  		gzip ${T1}
  		T1=${T1}.gz
	 	echo $T1
	else
 		echo ${anat} "is alread zipped. Ready for extraction."
 		T1=${anat}
 	fi

 ###extract the brain. $ANTSPATH must be defined
 ${ANTSPATH}antsBrainExtraction.sh -d 3 -a ${T1}  -e ${temp}  -m ${prob_mask} -o  ${prefix} -f $reg_mask
 
#rename output to ${file}_brain / ${file}_brain_mask
mv ${prefix}BrainExtractionBrain.nii.gz ${T1/.nii.gz/_brain.nii.gz}
brain=${T1/.nii.gz/_brain.nii.gz}
mv ${prefix}BrainExtractionMask.nii.gz ${T1/.nii.gz/_brain_mask.nii.gz}

fi