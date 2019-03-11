#!/bin/bash 
Usage() {
    echo " "
    echo "Usage: `basename $0` [options] -i <deniosed T1 Brain image> "
    echo ""
    echo " Compulsory Arguments "
    echo "-i <T1.nii.gz>                  : Image must include nii or nii.gz file extension "
    echo "-a <animal>"
 	
    echo " Optional Arguments" 
    echo "-p use priors. Indicate path to folder containing CSF,GM,and WM segmentations in standard space."
    echo " -t <0.??>			: Set a custom threshold. Default is 0.3"
   
    echo " " ##############potentially add opption to choose segmentation approach i.e ANTS or FAST############# 
    echo "Example:  `basename $0` -i pig_T1.nii.gz -t 0.3 "
    echo " "
    exit 1
}
if [ $# -lt 2 ] ; then Usage; exit 0; fi #### check that command is not called empty

NC=$(echo -en '\033[0m') #NC
RED=$(echo -en '\033[00;31m') #Red for error messages
animal=""
img=""
thresh=""
prior=""
#### parse them options
while getopts ":i:a:p:t:" opt ; do 
	case $opt in
		i)
			i=1;
			img=`echo $OPTARG`
			if [ ! -f ${img} ];then echo " "; echo " ${RED}CHECK INPUT FILE PATH ${NC}"; Usage; exit 1;fi ### check input file exists
			if [ "${img: -4}" == ".nii" ] || [ "${img: -7}" == ".nii.gz" ] ;then : ; else Usage; exit 1 ;fi
				;;
		a)
			a=1;
			animal=`echo $OPTARG`
			if [ ! -d ${PCP_PATH}/standards/${animal} ];then echo " "; echo " ${RED}CHECK STNADARDS FILE PATH ${NC}"; Usage; exit 1;fi ### check input file exists
				;;

		p)
			priors=`echo $OPTARG`
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
ruta=`pwd`
dir=$(dirname ${img})
cd ${dir} 
pwd

 T1=$(basename ${img})
if [ "$animal" = "" ];then echo "specify animal please";Usage;exit 1;fi

 #fslmaths ${T1} -mas $mask ${T1} ####mask the T1 image
 echo "checking and making necesary directory structure"
if [ -d seg ];then : ; else mkdir seg;fi
if [ -d mri ];then : ; else mkdir mri;fi
if [ -d surf ];then : ; else mkdir surf;fi


if [ "$priors" = "" ];then
	echo "FAST will be run without priors"
	echo $FSLDIR/bin/fast -n 3 -B -o ${ruta}/seg/seg ${ruta}/${T1}
else
	echo "priors activated"
	echo ${priors}
	if [ ! -d ${priors} ];then
		echo "Path to segmentation prior directory is incomplete or missing. Performing FAST with out priors"
		echo $FSLDIR/bin/fast -n 3 -B -o ${ruta}/seg/seg ${ruta}/${T1}
	fi
	if [ ! -f  ${priors}/csf.nii.gz ];then echo "no CSF mask found"; exit 1;fi
	if [ ! -f  ${priors}/gm.nii.gz ];then echo "no GM mask found"; exit 1;fi
	if [ ! -f  ${priors}/wm.nii.gz ];then echo "no WM mask found"; exit 1;fi
	echo "warping priors to anatomical space"


flirt -in $PCP_PATH/standards/${animal}/${animal}_brain -ref ${T1} -omat ${ruta}/seg/std2str.mat
mv ${ruta}/seg/std2str.mat ${ruta}/mri/transforms/std2str.mat
convert_xfm -omat ${ruta}/mri/transforms/str2std.mat -inverse ${ruta}/mri/transforms/std2str.mat
echo "SEGMENTING" ${animal}
$FSLDIR/bin/fast -n 3 -N  -a ${ruta}/mri/transforms/std2str.mat   -A ${priors}/csf.nii.gz  ${priors}/gm.nii.gz ${priors}/wm.nii.gz -o seg/seg ${ruta}/${T1}

fi





if [[ ${thresh} == "" ]];then 
	thresh=0.5
else
 :
fi



##### segment into 3 classes, WM, GM, CSF #######
# $FSLDIR/bin/fast -n 3 -B -o seg/seg ${ruta}/${T1}


###### threshold WM segmentation. Deault is 0.25, can be changed by user##########
$FSLDIR/bin/fslmaths seg/seg_pve_2.nii.gz -thr ${thresh} -bin mri/wm_orig

