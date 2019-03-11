#!/bin/bash

Usage() {
    echo " "
    echo "Usage: `basename $0` [options] -i <BrainT1 image> "
    echo ""
    echo " Compulsory Arguments "
    echo "-i <T1.nii.gz>                  : Image must include nii or nii.gz file extension "
 
    echo " Optional Arguments" 
    echo " -o <output_directory>          : Output directory. Default is directory of input image"
   
    echo " "
    echo "Example:  `basename $0` -i pig_T1.nii.gz -o pig_denoised.nii.gz "
    echo " "
    exit 1
}


if [ $# -lt 2 ] ; then Usage; exit 0; fi #### check that command is not called empty

NC=$(echo -en '\033[0m') #NC
RED=$(echo -en '\033[00;31m') #Red for error messages


img=""
out=""


#### parse them options
while getopts ":i:o:" opt ; do 
	case $opt in
		i)
			i=1;
			img=`echo $OPTARG`
			if [ ! -f ${img} ];then echo " "; echo " ${RED}CHECK INPUT FILE PATH ${NC}"; Usage; exit 1;fi ### check input file exists
			if [ "${img: -4}" == ".nii" ] || [ "${img: -7}" == ".nii.gz" ] ;then : ; else Usage; exit 1 ;fi
				;;

		o)  
			out=`echo $OPTARG`
			out=$(dirname $img)/${out}
			if [ -d ${out} ];then : ; else mkdir ${out} ;fi

				cp ${img} ${out}/
				;;
		\?)
		  echo "Invalid option:  -$OPTARG" 

		  	Usage
		  	exit 1
		  	;;

	esac 
done
### set output directory###### 
if [ ${i} -eq 1 ];then : ; else echo "${RED}-i is required input ${NC}" ; Usage; exit 2;fi
if [ "${out}" == "" ];then out=$(dirname $img) ;fi  ##### default output folder is the 

#set output directory
if [ "${out}" == $(dirname $img) ];then 
	img=${img}
else
	img=${out}/$(basename ${img})
fi

if [ "${img: -4}" == ".nii" ];then gzip ${img}; img=${img/.nii/.nii.gz};fi

 ### copy blank template of cat12 sanlm denoising script

 cd ${out} #### change working directory to output directory
 ruta=`pwd`/
echo ${ruta}
T1=$(basename $img)


echo "Using ANTS to denoise image"
${ANTSPATH}DenoiseImage -d 3 -i ${T1} -o sanlm_${T1} -v 1



