 #!/bin/bash 
source $FREESURFER_HOME/SetUpFreeSurfer.sh
######## this script is only meant to be run following brain extraction, denoising, Bias field correction and segmentation. 
######## This script is dependent on files generated in the previous outputs. 
#######  This is the beginning of Step 4 for surface generation i.e. filling. 
####### If you are unhappy with your surfaces then manually edit wm_orig.nii.gz and rerun this script and animal_tess.sh

Usage() {
    echo " "
    echo "Usage: `basename $0` [options] -i <T1_image> -x <Binary Mask>"
    echo ""
    echo " Compulsory Arguments "
    echo "-i <Denoised_Brain_T1_0N4.nii.gz>                  : Image must include nii or nii.gz file extension "
    echo "-a  < animal >                  : searches for directory of standards "
  
  

    echo " "
    echo " Optional Arguments"  ###### potentially add option to discard intermediate files? 
    echo " -c y                     include cerebellum and brain stem"
    echo "Example:  `basename $0` -i Denoised_Brain_T1_0N4.nii.gz -a pig "
    echo " "
    exit 1
}

if [ $# -lt 2 ] ; then Usage; exit 0; fi #### check that command is not called empty

NC=$(echo -en '\033[0m') #NC
RED=$(echo -en '\033[00;31m') #Red for error messages



####variables to be filled via options
img=""
animal=""
cb=""
#### parse them options
while getopts ":i:a:c:" opt ; do 
	case $opt in
		i) i=1;
			img=`echo $OPTARG`
			if [ ! -f ${img} ];then echo " "; echo " ${RED}CHECK INPUT FILE PATH ${NC}"; Usage; exit 1;fi ### check input file exists
			if [ "${img: -4}" == ".nii" ] || [ "${img: -7}" == ".nii.gz" ] ;then : ; else Usage; exit 1 ;fi
				;;
    a)
      a=1;
      animal=`echo $OPTARG`
      if [ ! -d ${PCP_PATH}/standards/${animal} ] && [ ${animal} != "masks" ] ;then echo " "; echo " ${RED}CHECK STNADARDS FILE PATH ${NC}"; Usage; exit 1;fi ### check input file exists
        ;;
		\?)
		  echo "Invalid option:  -$OPTARG" >&2

		  	Usage
		  	exit 1
		  	;;
	esac 
done

if [ "$animal" = "" ];then echo "specify animal please";Usage;exit 1;fi

subj=$(dirname ${img}) 
cd $subj
pwd

T1=$(basename ${img})
echo ${T1}

echo "here we go"

##### making the brain mask image. Must be brain extracted
if [ -f mri/filled-pretess127.mgz ];then
    echo "not first run"
    if [ -d mri/orig_res ];then
        echo "data was previously resampled"
        dim=$(fslinfo mri/brainmask.nii.gz |grep 'pixdim1'|awk '{print $2}')
        echo "resampling to " ${dim}
        cp ${T1} mri/brainmask.nii.gz 
        $FSLDIR/bin/flirt -in mri/brainmask.nii.gz  -ref mri/brainmask.nii.gz  -out mri/brainmask.nii.gz  -applyisoxfm ${dim}
    fi
else
    cp ${T1} mri/rawavg.nii.gz
    cp ${T1} mri/brainmask.nii.gz 
fi
cd mri/ 
if [ -f wm_orig.nii.gz ];then :; else  echo "Missing WM segmentation" `pwd`"/wm_orig.nii.gz";echo  "Please provide this required WM segmentation"; exit 1;fi

anat=`pwd`
anat=${anat/mri/}$T1
echo ${anat}
mri_dir=`pwd`

wm_seg=wm_orig.nii.gz
if [ -f ${mri_dir}/wm_hand_edit.nii.gz ];then 
	wm_seg=wm_hand_edit.nii.gz
	echo "using a hand edited WM segmentation for fill"
	mri_convert ${mri_dir}/wm_hand_edit.nii.gz ${mri_dir}/wm_hand_edit.mgz

fi
echo "##### THE WM SEG BEING USED IS " "${wm_seg}" " ##########"

echo "#####Converting FSL transform to LTA#####"
pwd
##convert fsl registrations for later use. note if planning to later resample to isometric these will be resampled to the isometric standard image####

#### use inital syn warps from brain extraction to split hemispheres and fill subcortical and non cortical material. #######



echo "warping standard masks for filling"
if [ -f filled-pretess127.mgz ];then
    echo "masks have already been registered"
else

    if [ ${animal} != "masks" ];then 
  ####deprecated. previously used actual translation to standard space.
  #### if wishing to make a group subject than make sure the commented out code is run to have an actual standard space matrix
  #lta_convert --infsl ${mri_dir}/transforms/str2std.mat --outlta ${mri_dir}/transforms/talairach.lta --src ${anat} --trg ${PCP_PATH}/standards/${animal}/${animal}_brain.nii.gz
  #lta_convert --infsl ${mri_dir}/transforms/str2std.mat --outmni ${mri_dir}/transforms/talairach.xfm --src ${anat} --trg ${PCP_PATH}/standards/${animal}/${animal}_brain.nii.gz
  #### new version uses identitiy matrix. Sep 13 2019
    lta_convert --infsl $FSLDIR/etc/flirtsch/ident.mat --outlta ${mri_dir}/transforms/talairach.lta --src ${anat} --trg ${PCP_PATH}/standards/${animal}/${animal}_brain.nii.gz
    lta_convert --infsl $FSLDIR/etc/flirtsch/ident.mat --outmni ${mri_dir}/transforms/talairach.xfm --src ${anat} --trg ${PCP_PATH}/standards/${animal}/${animal}_brain.nii.gz

    for mask in `ls $PCP_PATH/standards/${animal}/fill/*gz`;do 
        out=$(basename $mask)
        $FSLDIR/bin/flirt -in ${mask} -ref ${anat} -out ${mri_dir}/${out} -interp nearestneighbour -applyxfm -init ${mri_dir}/transforms/std2str.mat 
    done


    else

    echo " #######################USING SINGLE SUBJECT MASKS################"

    lta_convert --infsl ${mri_dir}/transforms/str2std.mat --outlta ${mri_dir}/transforms/talairach.lta --src ${anat} --trg ${anat}
    lta_convert --infsl ${mri_dir}/transforms/str2std.mat --outmni ${mri_dir}/transforms/talairach.xfm --src ${anat} --trg ${anat}


    for mask in `ls ..//masks/*gz`;do 
        out=$(basename $mask)
        echo ${out}
        $FSLDIR/bin/flirt -in ${mask} -ref ${anat} -out ${mri_dir}/${out} -interp nearestneighbour -applyxfm -init ${mri_dir}/transforms/std2str.mat 
    done

    fi
fi
# ##################################################################################################################### end necesary edits


echo "###### Normalizing T1 Intensities ######"
#### normalization of volume for use in freesurfer
upper=`fslstats brainmask -R | cut -d ' ' -f2-`
 echo "upper intensity value is " $upper 

 
echo "###### FILLING  WM #######"


 fslmaths brainmask -div $upper -mul 150 nu -odt int

 fslmaths nu -mas "${wm_seg}" nu_wm



  fslmaths "${wm_seg}" -add sub_cort -bin wm+SC
  fslmaths nu -mas wm+SC wm+SC_sub


  fslmaths "${wm_seg}" -mul 110 wm_110

  fslmaths wm+SC -bin -mul 110 wm_110+SC

 fslmaths nu -sub nu_wm -add wm_110 brain -odt int
 
 fslmaths nu -sub wm+SC_sub -add wm_110+SC brainmask -odt int


 echo "############# creating WM images for tesselation ###########"

 ### create WM image with sub_c intensity differences #####

 echo "######### filling WM ########"
 fslmaths "${wm_seg}" -sub sub_cort wm_nosubc
 fslmaths wm_nosubc -mul 110 wm_nosubc 
 fslmaths sub_cort -mul 250 sub_cort250
 fslmaths wm_nosubc -add sub_cort250 wm


fslmaths "${wm_seg}" -sub non_cort -thr 0 -bin  wm_pre_fill


fslmaths wm_pre_fill -add sub_cort250  -bin  wm_pre_fill

 fslmaths wm_pre_fill -fillh wm_pre_fill

 fslmaths wm_pre_fill -mas left_hem -mul 255 wm_left
 fslmaths wm_pre_fill -mas right_hem -mul 127 wm_right
 fslmaths wm_left -add wm_right filled

pwd

# ###conform images to isometric space if not already isometric
echo "###determining if image isometric. If not, resample to lowest dimension specified in header######"
#### we do this here to ensur that segmentations are performed at maximum resolution. 
#### however freesurfer works best on isometric data. So here we check and convert to isometric at native resolution,
function iso_check () {

  x=`fslinfo brainmask.nii.gz  |grep 'pixdim1'|awk '{print $2}'`
  y=`fslinfo brainmask.nii.gz  |grep 'pixdim2'|awk '{print $2}'`
  z=`fslinfo brainmask.nii.gz  |grep 'pixdim3'|awk '{print $2}'`

    ###determine if all dimensions the same. key value to return as decides whether or not to apply transforms
  resample=`echo "$x == $y && $x == $z" |bc -l`
  if [ ${resample} -eq 0 ];then
    order=`echo -e "${x}\n${y}\n${z}" |sort -g -r`
    max=`echo ${order} |awk '{print $1}'`
    echo "Data will be resampled to " ${max} "isometric"
    mkdir -p orig_res
    for i in `ls *gz`;do cp ${i} ./orig_res/$(basename $i) ; done 
  
  #resample to isometric resolution for surface generation. #note if this option is selected the talairach transforms will also be updated. ####
  for img in  `ls *.nii.gz`;do 
    $FSLDIR/bin/flirt -in ${img} -ref ${img} -out ${img} -applyisoxfm ${max} -interp nearestneighbour -noresampblur -omat ${mri_dir}/transforms/isometrize.mat
  done
  cp -r ${mri_dir}/transforms ${mri_dir}/orig_res/transforms


  cp ${mri_dir}/orig_res/rawavg.nii.gz ${mri_dir}/rawavg.nii.gz

  $FSLDIR/bin/convert_xfm  -omat  ${mri_dir}/transforms/inverse_iso.mat -inverse ${mri_dir}/transforms/isometrize.mat
  $FSLDIR/bin/convert_xfm -omat ${mri_dir}/transforms/str2std_iso.mat -concat ${mri_dir}/transforms/str2std.mat ${mri_dir}/transforms/inverse_iso.mat
  lta_convert --infsl $FSLDIR/etc/flirtsch/ident.mat  --outlta ${mri_dir}/transforms/talairach.lta --src brain.nii.gz --trg brain.nii.gz
  lta_convert --infsl $FSLDIR/etc/flirtsch/ident.mat  --outmni ${mri_dir}/transforms/talairach.xfm --src brain.nii.gz --trg brain.nii.gz
else
    echo "input data is isometric or has already been resampled"
fi

}
iso_check
echo "######final conversion for surface generation######"
pwd 

$FSLDIR/bin/fslmaths brain -mas left_hem left_brain
$FSLDIR/bin/fslmaths brain -mas right_hem right_brain

mri_convert brain.nii.gz  brain.mgz
 mri_convert brain.nii.gz  orig.mgz
 mri_convert brainmask.nii.gz brainmask.mgz   ###determining if image isometric.gz  brainmask.mgz
 mri_convert brain.nii.gz  brain.finalsurfs.mgz
 mri_convert left_brain.nii.gz  lh.brain.finalsurfs.mgz
 mri_convert right_brain.nii.gz  rh.brain.finalsurfs.mgz
 mri_convert brain.nii.gz  T1.mgz
 mri_convert brain.nii.gz  nu.mgz
 mri_convert wm.nii.gz wm.mgz
 mri_convert filled.nii.gz filled.mgz 
 mri_convert wm_orig.nii.gz wm_orig.mgz


 mri_dir=${subj}mri


 pwd
 mri_mask -T 5 brain.mgz brainmask.mgz brain.finalsurfs.mgz
 mri_pretess filled.mgz 255 T1.mgz filled-pretess255.mgz	
 mri_pretess filled.mgz 127 T1.mgz filled-pretess127.mgz
