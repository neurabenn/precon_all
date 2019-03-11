#!/bin/bash
set -e 
Usage() {
    echo " "
    echo "Usage: `basename $0` [options] -i <T1_image> -x <Binary Mask>"
    echo ""
    echo " Compulsory Arguments "
    echo "-i <T1.nii.gz>                  : Image must include nii or nii.gz file extension "
  
    echo "-x <binary brain mask>          : Binary brain mask defining region for Bias field. Typically a mask from brain extraction"
    echo " "
    echo " Optional Arguments" 
    echo " -o <output_directory>          : Output directory. Default is directory of input image"
    
    echo " -s < shrink factor>            : specify a shrink factor. Default is 0. For larger images reccomended 2."
    echo " "
    echo "Example:  `basename $0` -i pig_T1.nii.gz -x pig_binary_mask.nii.gz "
    echo " "
    exit 1
}

if [ $# -lt 4 ] ; then Usage; exit 0; fi #### check that command is not called empty

NC=$(echo -en '\033[0m') #NC
RED=$(echo -en '\033[00;31m') #Red for error messages



####variable to be filled via options
img=""
mask=""
out=""
shrink=""
#### parse them options
while getopts ":i:x:o:s:" opt ; do 
	case $opt in
		i) 
			i=1;
			img=`echo $OPTARG`
			if [ ! -f ${img} ];then echo " "; echo " ${RED}CHECK INPUT FILE PATH ${NC}"; Usage; exit 1;fi ### check input file exists
			if [ "${img: -4}" == ".nii" ] || [ "${img: -7}" == ".nii.gz" ] ;then : ; else Usage; exit 1 ;fi
				;;
		x) 
			x=1;
			mask=`echo $OPTARG`
			if [ ! -f ${mask} ];then echo " "; echo " ${RED}CHECK INPUT FILE PATH ${NC}"; Usage; exit 1;fi ### check input file exists
			if [ "${mask: -4}" == ".nii" ] || [ "${mask: -7}" == ".nii.gz" ] ;then : ; else Usage; exit 1 ;fi
				;;

		o)  
			out=`echo $OPTARG`
			out=$(dirname $img)/${out}
			if [ -d ${out} ];then : ; else mkdir ${out} ;fi

				cp ${img} ${out}/
				cp ${mask} ${out}/
				;;
		s) 
			shrink=`echo $OPTARG` #### shrink factor for B field correctoin in ants. Recommended 0 for small images. Maximum 4.
			
			if [ ${shrink} -le 4  ] && [ ${shrink} -ge 0 ];then 
				:
			else
				echo " ${RED}SHRINK FACTOR MUST BE BETWEEN 0-4${NC}"
				Usage
				exit 1 
			fi

				;;
		\?)
		  echo "Invalid option:  -$OPTARG" >&2

		  	Usage
		  	exit 1
		  	;;

	esac 
done

if [ ${i} -eq 1 ];then : ; else echo "${RED}-i is required input ${NC}" ; Usage; exit 2;fi
if [ ${x} -eq 1 ];then : ; else echo "${RED}-x is required input ${NC}" ; Usage; exit 2;fi


if [ "${out}" == "" ];then out=$(dirname $img) ;fi  ##### default output folder is the 

#set output directory
if [ "${out}" == $(dirname $img) ];then 
	img=${img}
	mask=${mask}
else

	cp ${img} ${out}
	img=${out}/$(basename ${img})
	mask=${out}/$(basename ${mask})
fi

if [ "${img: -4}" == ".nii" ];then gzip ${img}; img=${img/.nii/.nii.gz};fi
if [ "${mask: -4}" == ".nii" ];then gzip ${mask}; mask=${mask/.nii/.nii.gz};fi



			 ####mask the T1 image to remove any remaining non brain voxels####
$FSLDIR/bin/fslmaths $img -mas $mask $img 
echo ${img}
echo ${mask}

#### truncate image instensity prior to bias field correction 
 ${ANTSPATH}ImageMath 3 ${img/.nii.gz/}_0N4.nii.gz TruncateImageIntensity $img 0.025 0.995 256 $mask 1

 T1=${img/.nii.gz/}_0N4.nii.gz
echo ${T1}
# reregister your brain mask to the brain to be safe in the N4 call
#  Perform Bias field correction
if [[ ${shrink} == "" ]];then

	 echo ${ANTSPATH}N4BiasFieldCorrection -d 3 -i $T1 -x $mask  -c [100x100x100x100,0.0000000001] -b [200] -o $T1 --verbose 0
	 ${ANTSPATH}N4BiasFieldCorrection -d 3 -i $T1   -c [100x100x100x100,0.0000000001] -b [200] -o $T1 --verbose 0 
	 fslmaths ${T1} -mas ${mask} ${T1}
	
else

	echo ${ANTSPATH}N4BiasFieldCorrection -d 3 -i $T1 -x $mask  -s ${shrink}  -c [100x100x100x100,0.0000000001] -b [200] -o $T1 --verbose 0
	${ANTSPATH}N4BiasFieldCorrection -d 3 -i $T1   -s ${shrink}  -c [100x100x100x100,0.0000000001] -b [200] -o $T1 --verbose 0 
	fslmaths ${T1} -mas ${mask} ${T1}
 fi

