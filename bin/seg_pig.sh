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
    echo " -t <0.??>			: Set a custom threshold. Default is 0.5 for FAST and 0.1 in ANTs"
    echo " -s 					: Run ANTs AtroposN4 instead of FSL FAST. (Can be slower) "
   
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
use_ants=""
#### parse them options
while getopts ":i:a:p:t:s" opt ; do 
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
			if [ ! -d ${PCP_PATH}/standards/${animal} ] && [ ${animal} != "masks" ];then echo " "; echo " ${RED}CHECK STANDARDS FILE PATH ${NC}"; Usage; exit 1;fi ### check input file exists
				;;

		p)
			priors=`echo $OPTARG`
				;;



		t)  
			thresh=`echo $OPTARG`
				;;
		s)  s=1;
          ants_seg="y"
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

#### check the thresholding. if none, than use 0.5
if [[ ${thresh} == "" ]];then
 thresh=0.5 
else :
fi


 T1=$(basename ${img})
if [ "$animal" = "" ];then echo "specify animal please";Usage;exit 1;fi

 #fslmaths ${T1} -mas $mask ${T1} ####mask the T1 image
 echo "checking and making necesary directory structure"
if [ -d seg ];then : ; else mkdir seg;fi
if [ -d mri ];then : ; else mkdir mri;fi
if [ -d surf ];then : ; else mkdir surf;fi


##### check to see if the masks were supplied as a one off 
if [ ${animal} = masks ];then
	cp $FSLDIR/etc/flirtsch/ident.mat ${ruta}/mri/transforms/std2str.mat
	cp $FSLDIR/etc/flirtsch/ident.mat ${ruta}/mri/transforms/str2std.mat

###### basic registration to standard. 
###### needed whtehr or not priors are specified
###### used for moving sub_cort, non_cort, and hemisphere masks into place 
else
flirt -in $PCP_PATH/standards/${animal}/${animal}_brain -ref ${T1} -omat ${ruta}/seg/std2str.mat -searchrx -180 180 -searchry -180 180 -searchrz -180 180
mv ${ruta}/seg/std2str.mat ${ruta}/mri/transforms/std2str.mat
convert_xfm -omat ${ruta}/mri/transforms/str2std.mat -inverse ${ruta}/mri/transforms/std2str.mat
fi

##### now we're checking for priors ####
if [ "$priors" = "" ];then
	echo "SEGMENTING without priors"

	echo "### echo no priors here#### FIRT CHECK ##### INSERTING ANTS ##### "
	
	##### insert ants check here
	if [[ ${ants_seg} == "y" ]];then 
		echo "SEGMENTING" ${animal} "USING ANTS"
		echo "in following dir"
		echo "the threshold is " ${thresh}
		mask=`ls *brain_mask*`
		##### doing the segmentation
		#### make sure extraction mask is binary prior to segmenting
		$FSLDIR/bin/fslmaths ${mask} -bin seg/seg_mask.nii.gz
		${ANTSPATH}/antsAtroposN4.sh -d 3  -x seg/seg_mask.nii.gz -a ${ruta}/${T1} -c 3 -o seg/ -w 0.25 
		$FSLDIR/bin/fslmaths ./seg/SegmentationPosteriors3.nii.gz -thr ${thresh} -bin mri/wm_orig
	else

		echo "SEGMENTING WITH FAST"
		 $FSLDIR/bin/fast -n 3 -N -o ${ruta}/seg/seg ${ruta}/${T1}
		 $FSLDIR/bin/fslmaths ./seg/seg_pve_2.nii.gz -thr ${thresh} -bin mri/wm_orig
		fi
else
	echo "priors activated"
	echo ${priors}

	if [ ! -d ${priors} ];then
	#### check folder where priors should exist. if not there will run without priors
		echo "Path to segmentation prior directory is incomplete or missing. Performing FAST with out priors"
		echo "### no priors here##### SECOND CHECK ####### INSERTING ANTS ##### "
		
		#### insert ants check here

		echo $FSLDIR/bin/fast -n 3 -N -o ${ruta}/seg/seg ${ruta}/${T1}
	
	fi
	if [ ! -f  ${priors}/csf.nii.gz ];then echo "no CSF mask found"; exit 1;fi
	if [ ! -f  ${priors}/gm.nii.gz ];then echo "no GM mask found"; exit 1;fi
	if [ ! -f  ${priors}/wm.nii.gz ];then echo "no WM mask found"; exit 1;fi
	echo "warping priors to anatomical space"

########################################## check modality. for T1 or T2. ###################


######### insert ants check here

echo "### priors are being used. ADDING ANTS HERE####"

	if [[ ${ants_seg} == "y" ]];then 
	echo "SEGMENTING" ${animal} "USING ANTS"
	echo "in following dir"
	pwd
	
	echo "the threshold is " ${thresh}
	mask=`ls *brain_mask*`
	## warp the priors for use with ants. this step isn't nececessary for FAST
	
	if [ -f ${ruta}/mri/transforms/std2str_warp.nii.gz ];then
		##### if a non linear warp exists use it on the priors
		echo "##### warping priors via on linear warp #####"
		$FSLDIR/bin/applywarp -i ${priors}/csf.nii.gz  -r ${T1} -w ${ruta}/mri/transforms/std2str_warp.nii.gz  -o ./seg/priors1.nii.gz
		$FSLDIR/bin/applywarp -i ${priors}/gm.nii.gz  -r ${T1} -w ${ruta}/mri/transforms/std2str_warp.nii.gz  -o ./seg/priors2.nii.gz
		$FSLDIR/bin/applywarp -i ${priors}/wm.nii.gz  -r ${T1} -w ${ruta}/mri/transforms/std2str_warp.nii.gz  -o ./seg/priors3.nii.gz 
		$FSLDIR/bin/fslmaths ./seg/priors3.nii.gz  -thr 0.01 -bin ./seg/priors3.nii.gz 
	else
		echo "##### using linear transform of priors #####"
		$FSLDIR/bin/applywarp -i ${priors}/csf.nii.gz  -r ${T1} --premat=${ruta}/mri/transforms/std2str.mat -o ./seg/priors1.nii.gz
		$FSLDIR/bin/applywarp -i ${priors}/gm.nii.gz  -r ${T1} --premat=${ruta}/mri/transforms/std2str.mat -o ./seg/priors2.nii.gz
		$FSLDIR/bin/applywarp -i ${priors}/wm.nii.gz  -r ${T1} --premat=${ruta}/mri/transforms/std2str.mat -o ./seg/priors3.nii.gz 
		$FSLDIR/bin/fslmaths ./seg/priors3.nii.gz  -thr 0.01 -bin ./seg/priors3.nii.gz 
	fi

	$FSLDIR/bin/fslmaths ${mask} -bin seg/seg_mask.nii.gz
	# $FSLDIR/bin/fslmaths ./seg/priors3.nii.gz -bin ./seg/priors3.nii.gz
	${ANTSPATH}/antsAtroposN4.sh -d 3  -x seg/seg_mask.nii.gz -a ${ruta}/${T1} -c 3 -o seg/ -p ./seg/priors%d.nii.gz -w 0.25
	$FSLDIR/bin/fslmaths ./seg/SegmentationPosteriors3.nii.gz -thr ${thresh} -bin mri/wm_orig

	
	else
		echo "SEGMENTING" ${animal} "USING FAST"
		$FSLDIR/bin/fast -n 3 -N  -a ${ruta}/mri/transforms/std2str.mat   -A ${priors}/csf.nii.gz  ${priors}/gm.nii.gz ${priors}/wm.nii.gz -o seg/seg ${ruta}/${T1}
		$FSLDIR/bin/fslmaths ./seg/seg_pve_2.nii.gz -thr ${thresh} -bin mri/wm_orig
	
	fi

fi
