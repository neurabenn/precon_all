#!/bin/bash 
Usage() {
    echo " "
    echo "Usage: `basename $0` [options] -i <deniosed T1 Brain image> "
    echo ""
    echo " Compulsory Arguments "
    echo "-i <T1.nii.gz>                  : Image must include nii or nii.gz file extension "
 	
    echo " Optional Arguments" 
    echo " -t <0.??>			: Set a custom threshold. Default is 0.25"
   
    echo " " ##############potentially add opption to choose segmentation approach i.e ANTS or FAST############# 
    echo "Example:  `basename $0` -i pig_T1.nii.gz -t 0.25 "
    echo " "
    exit 1
}
if [ $# -lt 2 ] ; then Usage; exit 0; fi #### check that command is not called empty

NC=$(echo -en '\033[0m') #NC
RED=$(echo -en '\033[00;31m') #Red for error messages

img=""
thresh=""
#### parse them options
while getopts ":i:t:" opt ; do 
	case $opt in
		i)
			i=1;
			img=`echo $OPTARG`
			if [ ! -f ${img} ];then echo " "; echo " ${RED}CHECK INPUT FILE PATH ${NC}"; Usage; exit 1;fi ### check input file exists
			if [ "${img: -4}" == ".nii" ] || [ "${img: -7}" == ".nii.gz" ] ;then : ; else Usage; exit 1 ;fi
				;;

		t)  
			thresh=`echo $OPTARG`
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

dir=$(dirname ${img})
cd ${dir} 
pwd

 T1=$(basename ${img})


 #fslmaths ${T1} -mas $mask ${T1} ####mask the T1 image
if [ -d seg ];then : ; else mkdir seg;fi
if [ -d mri ];then : ; else mkdir mri;fi
if [ -d surf ];then : ; else mkdir surf;fi

if [[ ${thresh} == "" ]];then 
	thresh=0.25
else
 :
fi
ruta=`pwd`
##### segment into 3 classes, WM, GM, CSF #######
fast -n 3 -B -o seg/seg ${ruta}/${T1}

###### threshold WM segmentation. Deault is 0.25, can be changed by user##########
fslmaths seg/seg_pve_2.nii.gz -thr ${thresh} -bin mri/wm_orig

