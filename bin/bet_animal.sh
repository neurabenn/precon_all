#!/bin/bash 
Usage() {
    echo " "
    echo "Usage: `basename $0` [options] -i <T1_image> "
    echo ""
    echo " Compulsory Arguments "
    echo "-i <T1.nii.gz>                  :Compulsory input, Image must include nii or nii.gz file extension "
    echo " "
    echo "-a <animal> "
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

while getopts ":i:a:p:o:d:" opt ; do 
	case $opt in
		i) 
			i=1;
			img=`echo $OPTARG`
			if [ ! -f ${img} ];then echo " "; echo "${RED}CHECK INPUT FILE PATH ${NC}"; Usage; exit 1;fi ### check input file exists
			if [ "${img: -4}" == ".nii" ] || [ "${img: -3}" == ".gz" ] ;then : ; else Usage; exit 1 ;fi
			;;
		a) 
			a=1;
			animal=`echo $OPTARG`
			if [ ! -d $PCP_PATH/standards/${animal} ];then echo " "; echo "${RED}CHECK that there is a valid non standard template directory ${NC}"; Usage; exit 1;fi ### check input file exists
			if [ "${img: -4}" == ".nii" ] || [ "${img: -3}" == ".gz" ] ;then : ; else Usage; exit 1 ;fi
			;;
		p)
		
			prefix=`echo $OPTARG`
			;;
		o) >&2
			out=`echo $OPTARG`
			# out=$(dirname $img)/${out}
			
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
if [ ${a} -eq 1 ];then : ; else echo "${RED}-i is required input ${NC}" ; Usage; exit 2;fi


if [ "${prefix}" == "" ];then prefix="extract" ;fi #### default prefix of extracted file is extract
if [ "${out}" == "" ];then out=$(dirname $img) ;fi  ##### default output folder is the 
if [ "${denoise}" == "" ];then denoise="y" ;fi #### default is to denoise full body image prior to brain extraction

##########template and mask files for extraction ###########
######### future versions of this script will allow for customizable templates to be used int he brain extraction process. 
######### for now if you desire other species to have their brain extracted change each file accordingly
temp=${PCP_PATH}/standards/${animal}/extraction/${animal}_temp.nii.gz ########## whole body template image for registration
prob_mask=${PCP_PATH}/standards/${animal}/extraction/brain_mask.nii.gz ######probablistic extraction mask. If you don't have one you can make one via smoothing a prior brain extraction binary mask
reg_mask=${PCP_PATH}/standards/${animal}/extraction/reg_mask.nii.gz ######### full body registration mask


if [ ${out} = "" ];then out=`pwd`;fi

if [ ! -d ${out} ];then mkdir -p ${out};fi 




echo "############## USING FNIRT NOT ANTS NOW!!!!!!!! ##############"
T1=$(basename ${img})
cd ${out}
mkdir -p mri/transforms

echo ${T1}


${ANTSPATH}N4BiasFieldCorrection -d 3 -i ${T1}  -c [100x100x100x100,0.0000000001] -b [200] -o ${T1} --verbose 0
$ANTSPATH/DenoiseImage -d 3 -i ${T1} -o sanlm_${T1}
$ANTSPATH/ImageMath  3 sanlm_${T1} TruncateImageIntensity sanlm_${T1} 0.05 0.999 

$FSLDIR/bin/flirt -in sanlm_${T1} -ref ${temp} -dof 12  -omat mri/transforms/init.mat -searchrx -180 180 -searchry -180 180 -searchrz -180 180 -out str_2std_linear
$FSLDIR/bin/fnirt --in=sanlm_${T1} --ref=${temp} --aff=mri/transforms/init.mat --cout=mri/transforms/str2std_warp
$FSLDIR/bin/invwarp --warp=mri/transforms/str2std_warp --ref=sanlm_${T1} --out=mri/transforms/std2str_warp
$FSLDIR/bin/applywarp --in=${prob_mask} --ref=sanlm_${T1}  --interp=nn --warp=mri/transforms/std2str_warp --out=${T1/.nii.gz/_brain_mask}
$FSLDIR/bin/fslmaths sanlm_${T1} -mas ${T1/.nii.gz/_brain_mask}  ${T1/.nii.gz/_brain}


echo " End brain extraction "



# outbrain=${out}/(basename ${img})
# echo ${outbrain}

# $FSLDIR/bin/fslmaths ${out}/sanlm_$(basename ${img}) -mas ${out}/brain_mask  ${outbrain/.nii.gz/_brain} 






# T1=$(basename ${img})

# echo ${T1}
# echo ${out}
# #  ### if requested denoise input image


#  if [ "${denoise}" == "y" ];then

#  	${ANTSPATH}DenoiseImage -d 3 -i ${T1} -o ${out}/sanlm_${T1} -v 1
# 	T1=sanlm_${T1}
# # 	###### prepare extraction variables ########### 

# # pwd 
# fi
# echo ${T1}

# cd ${out}
# pwd
 
# ###extract the brain. $ANTSPATH must be defined	
# # pwd
# ${ANTSPATH}antsBrainExtraction.sh -d 3 -a ${T1}  -e ${temp}  -m ${prob_mask} -o  ${out}/${prefix}/${prefix} -f $reg_mask -k 1
# # pwd
# # #rename output to ${file}_brain / ${file}_brain_mask
# if [ "${denoise}" == "y" ];then
# 	T1=${T1/sanlm_/}
# 	mv ${prefix}/${prefix}BrainExtractionBrain.nii.gz ${T1/.nii.gz/_brain.nii.gz}
# 	mv ${prefix}/${prefix}BrainExtractionMask.nii.gz ${T1/.nii.gz/_brain_mask.nii.gz}
# else
# 	T1=${T1}
# 	mv ${prefix}/${prefix}BrainExtractionBrain.nii.gz ${T1/.nii.gz/_brain.nii.gz}
# 	mv ${prefix}/${prefix}BrainExtractionMask.nii.gz ${T1/.nii.gz/_brain_mask.nii.gz}
# fi


# mv ${prefix}/${prefix}BrainExtractionPrior0GenericAffine.mat mri/transforms/ANTSitkGeneric.mat
# mv ${prefix}/${prefix}BrainExtractionPrior0GenericAffine.mat mri/transforms/ANTSitkGeneric.mat
# mv ${prefix}/${prefix}BrainExtractionPrior1InverseWarp.nii.gz mri/transforms/ANTSitkInverseWARP.nii.gz




