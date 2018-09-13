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
    echo "Example:  `basename $0` -i pig_T1.nii.gz -o pig_binary_mask.nii.gz "
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


  gunzip $T1
   T1=${T1/.gz/}
   echo $T1


   #### CAT!@ is a matlab script. as AMTLAB does not allow for varibale to start with digits check and temporarily rename the file for the purposes of denoising.
   first_char=`echo ${T1} | head -c 1`


if [[ $first_char == [a-z] ]] || [[ $first_char == [A-Z] ]] ;then 
   	sub=${ruta}${T1}
	echo ${sub}
	name=$(basename ${img})
	name=${name/.nii/}
	cp ${PCP_PATH}mat_files/denoise_temp.m ${out}/${name/brain/}_denoise_sanlm.m 
 	echo "denoising " $sub
  	sed -i -e  "s+'<UNDEFINED>'+{'${sub},1'}+g" ${name/brain/}_denoise_sanlm.m 
 	sh ${CAT12_PATH}cat_batch_spm_fg.sh ${name/brain/}_denoise_sanlm.m 
 	gzip ${sub} ### reszip non denoised image
	gzip sanlm_${T1} 
 else 
 	echo ${first_char} "Is a number. creating a temporary name for the file to be denoised"
	sub=${ruta}${T1}
	cp ${sub} ${ruta}tmp${T1}
	sub_new=${ruta}tmp${T1}
	echo ${sub_new}
	name=$(basename ${sub_new})
	name=${name/.nii/}
	cp ${PCP_PATH}mat_files/denoise_temp.m ${out}/${name/brain/}_denoise_sanlm.m 
 	echo "denoising " $sub_new
 	sed -i -e  "s+'<UNDEFINED>'+{'${sub_new},1'}+g" ${name/brain/}_denoise_sanlm.m 
 	sh ${CAT12_PATH}cat_batch_spm_fg.sh ${name/brain/}_denoise_sanlm.m
 	mv ${ruta}sanlm_tmp${T1} ${ruta}sanlm_${T1} ### return back to expected format of naming convention
	gzip ${ruta}sanlm_${T1}
	echo rm ${sub_new} 
	gzip ${sub}
 fi



