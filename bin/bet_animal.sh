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
    echo " -m <y/n>                       : do you have a predefined initial  "
	echo " -e 							  : Use ANTs for brain extraction and warps."
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
premat=""
ants_enabled=""


#### define options for running script

while getopts ":i:a:p:o:d:m:e" opt ; do 
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
		m) >&2
			premat=`echo $OPTARG`
			if [ "${premat}" != "" ];then echo "a pre_extraction matrix has been specified";fi
			;;
		e) 
			ants_enabled=1
			echo "ANTs brain extraction enabled"
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
temp=${PCP_PATH}/standards/${animal}/extraction/${animal}_temp.nii.gz ########## whole body template image for registration
temp_brain_extracted=${PCP_PATH}/standards/${animal}/extraction/${animal}_brain.nii.gz
prob_mask=${PCP_PATH}/standards/${animal}/extraction/brain_mask.nii.gz ######probablistic extraction mask. If you don't have one you can make one via smoothing a prior brain extraction binary mask
reg_mask=${PCP_PATH}/standards/${animal}/extraction/reg_mask.nii.gz ######### full body registration mask


if [ ${out} = "" ];then out=`pwd`;fi

if [ ! -d ${out} ];then mkdir -p ${out};fi 




T1=$(basename ${img})
cd ${out}
mkdir -p mri/transforms

echo ${T1}


${ANTSPATH}/DenoiseImage -d 3 -i ${T1} -o sanlm_${T1} -v


$FSLDIR/bin/fslmaths sanlm_${T1} -thr 0 sanlm_${T1}
$FSLDIR/bin/fslorient -copyqform2sform sanlm_${T1}


if [ "${ants_enabled}" != "1" ]; then
	if [[  -f ${premat}  ]] ;then

		echo "##### Using a pre_extraction matrix ########"
		mask="$(dirname ${premat})/regmask.nii.gz"
		echo "using pre_extract.mat as initial transform"

		if [ -f ${mask} ];then
			echo "##### USING A REGISTRATION MASK FOR FNIRT ######"
			applywarp --in=${mask} --ref=${temp} --interp=nn --out=${mask/.nii.gz/_std.nii.gz} --premat=${premat}
			echo $FSLDIR/bin/fnirt --in=sanlm_${T1} --ref=${temp}  --cout=mri/transforms/str2std_warp --aff=${premat}  --applyinmask=${mask} --applyrefmask=${mask/.nii.gz/_std.nii.gz}
			$FSLDIR/bin/fnirt --in=sanlm_${T1} --ref=${temp}  --cout=mri/transforms/str2std_warp --aff=${premat}  --applyinmask=${mask} --applyrefmask=${mask/.nii.gz/_std.nii.gz}
		else
			echo $FSLDIR/bin/fnirt --in=sanlm_${T1} --ref=${temp}  --cout=mri/transforms/str2std_warp --aff=${premat}
			$FSLDIR/bin/fnirt --in=sanlm_${T1} --ref=${temp}  --cout=mri/transforms/str2std_warp --aff=${premat} 
		fi
		
	else
		
		echo "#### no pre_Extraction matrix used -- run initial brain extraction with ants to get an initialization matrix"
		$FSLDIR/bin/flirt -in sanlm_${T1} -ref ${temp} -dof 12  -omat mri/transforms/init.mat -searchrx -180 180 -searchry -180 180 -searchrz -180 180 -out str_2std_linear
		$FSLDIR/bin/fnirt --in=sanlm_${T1} --ref=${temp}  --cout=mri/transforms/str2std_warp -v --aff=mri/transforms/init.mat
		

	fi

	$FSLDIR/bin/invwarp --warp=mri/transforms/str2std_warp --ref=sanlm_${T1} --out=mri/transforms/std2str_warp
	$FSLDIR/bin/applywarp --in=${prob_mask} --ref=sanlm_${T1}  --interp=nn --warp=mri/transforms/std2str_warp --out=${T1/.nii.gz/_brain_mask}
	$FSLDIR/bin/fslmaths sanlm_${T1} -mas ${T1/.nii.gz/_brain_mask}  ${T1/.nii.gz/_brain}
	${ANTSPATH}/ImageMath  3 sanlm_${T1} TruncateImageIntensity sanlm_${T1}  0.05 0.999
else
	echo "Brain extraction with ANTs"
	if [[  -f ${premat}  ]] ;then
		echo "using premat / initial registration to guide brain extraction"
		lta_convert --infsl ${premat} --outitk mri/transforms/pre_extract.txt --src sanlm_${T1} --trg ${temp}
		ConvertTransformFile 3 mri/transforms/pre_extract.txt mri/transforms/pre_extract.mat --convertToAffineType
		${ANTSPATH}/antsBrainExtraction.sh -d 3 -e ${temp} -a sanlm_${T1} -m ${prob_mask} -o ANTs  -r mri/transforms/pre_extract.mat  
	else
		echo "extracting brain -- no pre registration matrix"
		${ANTSPATH}/antsBrainExtraction.sh -d 3 -e ${temp} -a sanlm_${T1} -m ${prob_mask} -o ANTs 	
	fi
		
	## cleanup 
	mv ANTsBrainExtractionPrior0GenericAffine.mat mri/transforms/
	mv ANTsBrainExtractionMask.nii.gz ${T1/.nii.gz/_brain_mask}.nii.gz
	mv ANTsBrainExtractionBrain.nii.gz ${T1/.nii.gz/_brain}.nii.gz
	echo "registering to template"
	fslmaths ${prob_mask} -bin std_brain_mask.nii.gz

	${ANTSPATH}/antsRegistrationSyN.sh -d 3 -f ${temp} -m sanlm_${T1} -x std_brain_mask.nii.gz,${T1/.nii.gz/_brain_mask}.nii.gz -o mri/transforms/ANTsREG
	rm std_brain_mask.nii.gz
	${PCP_PATH}/bin/ants_to_fsl_warp.sh ${temp} sanlm_${T1} mri/transforms/ANTsREG1Warp.nii.gz mri/transforms/ANTsREG0GenericAffine.mat 
	$FSLDIR/bin/fslmaths sanlm_${T1} -mas ${T1/.nii.gz/_brain_mask}  ${T1/.nii.gz/_brain}
	

fi
echo " End brain extraction "

### above is legacy... we're going to add an ANTs module / option. 

# #### insert ants brain extraction here to get a premat 
	  ## done with debugging mode. goal is to get better initial reg
# 	$FSLDIR/bin/fslorient -copyqform2sform ANTsBrainExtractionBrain.nii.gz
# 	$FSLDIR/bin/flirt -in ANTsBrainExtractionBrain.nii.gz -ref ${temp_brain_extracted} -dof 12  -omat mri/transforms/init.mat -out str_2std_linear
	
# 	$FSLDIR/bin/fnirt --in=sanlm_${T1} --ref=${temp}  --cout=mri/transforms/str2std_warp_init -v --aff=mri/transforms/init.mat