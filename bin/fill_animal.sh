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
    echo "-L  Left side only"
    echo "-R  Right Side only "


  
  

    echo " "
    echo " Optional Arguments"  ###### potentially add option to discard intermediate files? 
    echo " -c y                     include cerebellum and brain stem"
    echo "Example:  `basename $0` -i Denoised_Brain_T1_0N4.nii.gz -a pig "
    echo " "
    
}

function iso_check () {
  ############ fucntion checks if image is isotropic, and if not resamples to the largest dimension present in the image. 
img=${1}
  x=`fslinfo ${img}  |grep 'pixdim1'|awk '{print $2}'`
  y=`fslinfo ${img}  |grep 'pixdim2'|awk '{print $2}'`
  z=`fslinfo ${img}  |grep 'pixdim3'|awk '{print $2}'`

    ###determine if all dimensions the same. key value to return as decides whether or not to apply transforms
  resample=`echo "$x == $y && $x == $z" |bc -l`
  if [ ${resample} -eq 0 ];then
    echo "###################### RESAMPLE FACTOR IS " ${resample}
    order=`echo -e "${x}\n${y}\n${z}" |sort -g -r`
    max=`echo ${order} |awk '{print $1}'`
    echo ${img} "will be resampled to " ${max} "isometric"
    mkdir -p orig_res/transforms
    cp ${img} orig_res/$(basename ${img})
    ### do the resampling
    $FSLDIR/bin/flirt -in ${img} -ref ${img} -out ${img} -applyisoxfm ${max} -interp nearestneighbour -noresampblur -omat ${mri_dir}/transforms/isometrize.mat
    cp  ${mri_dir}/transforms/* ${mri_dir}/orig_res/transforms

  $FSLDIR/bin/convert_xfm  -omat  ${mri_dir}/transforms/inverse_iso.mat -inverse ${mri_dir}/transforms/isometrize.mat
  $FSLDIR/bin/convert_xfm -omat ${mri_dir}/transforms/str2std_iso.mat -concat ${mri_dir}/transforms/str2std.mat ${mri_dir}/transforms/inverse_iso.mat
  lta_convert --infsl $FSLDIR/etc/flirtsch/ident.mat  --outlta ${mri_dir}/transforms/talairach.lta --src ${mri_dir}/brain.nii.gz --trg ${mri_dir}/brain.nii.gz
  lta_convert --infsl $FSLDIR/etc/flirtsch/ident.mat  --outmni ${mri_dir}/transforms/talairach.xfm --src ${mri_dir}/brain.nii.gz --trg ${mri_dir}/brain.nii.gz
  
  #resample to isometric resolution for surface generation. #note if this option is selected the talairach transforms will also be updated. ####
else
    echo ${img} "is isotropic or has already been resampled"
fi

}

if [ $# -lt 2 ] ; then Usage; exit 0; fi #### check that command is not called empty

NC=$(echo -en '\033[0m') #NC
RED=$(echo -en '\033[00;31m') #Red for error messages

####variables to be filled via options
img=""
animal=""
cb=""
L_only=""
R_only=""
#### parse them options
while getopts ":i:a:c:LR" opt ; do 
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
     L)
          L_only="y"
                ;;
      R)  R=1
          R_only="y"
                ;;
		\?)
		  echo "Invalid option:  -$OPTARG" >&2

		  	Usage
		  	exit 1
		  	;;
	esac 
done


if [ "$animal" = "" ];then echo "specify animal please";Usage;exit 1;fi



side=(left right)
if [[ ${L_only} == "y" ]];then echo "Left only"; side=(left);fi
if [[ ${R_only} == "y" ]];then echo "Right only "; side=(right);fi
echo ${side[*]}


subj=$(dirname ${img}) 
cd $subj
pwd

T1=$(basename ${img})
echo ${T1}

echo "here we go"

#### making the brain mask image. Must be brain extracted
if [ -f mri/brain.finalsurfs.mgz ];then
    echo "not first run"
    if [ -d mri/orig_res ];then
        echo "This is not the first run of precon"
        # dim=$(fslinfo mri/brainmask.nii.gz |grep 'pixdim1'|awk '{print $2}')
        # echo "data was resampled to " ${dim} "isotropic"
        cp ${T1} mri/brainmask.nii.gz 
        cp ${T1} mri/rawavg.nii.gz
        # $FSLDIR/bin/flirt -in mri/brainmask.nii.gz  -ref mri/brainmask.nii.gz  -out mri/brainmask.nii.gz  -applyisoxfm ${dim}
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
  iso_check ${mri_dir}/wm_hand_edit.nii.gz 
	wm_seg=wm_hand_edit.nii.gz
	echo "using a hand edited WM segmentation for fill"
	mri_convert ${mri_dir}/wm_hand_edit.nii.gz ${mri_dir}/wm_hand_edit.mgz
fi
echo "##### THE WM SEG BEING USED IS " "${wm_seg}" " ##########"

echo "#####Converting FSL transform to LTA#####"
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

      ##### editing in january 2020#####
    ##### current code means surface transform doesn't propoerly match volume#####
    ##### added line at 300 to hopefully correct ######
    lta_convert --infsl $FSLDIR/etc/flirtsch/ident.mat --outlta ${mri_dir}/transforms/talairach.lta --src ${anat} --trg ${anat} 
    lta_convert --infsl $FSLDIR/etc/flirtsch/ident.mat --outmni ${mri_dir}/transforms/talairach.xfm --src ${anat} --trg ${anat} 

    for mask in `ls $PCP_PATH/standards/${animal}/fill/*gz`;do 
        out=$(basename $mask)
        $FSLDIR/bin/flirt -in ${mask} -ref ${anat} -out ${mri_dir}/${out}  -applyxfm -init ${mri_dir}/transforms/std2str.mat 
        $FSLDIR/bin/fslmaths ${mri_dir}/${out}  -thr 0.3 -bin ${mri_dir}/${out}  
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

for img in `ls *.nii.gz`;do 
  iso_check ${img}
done

echo "###### Normalizing T1 Intensities ######"
#### normalization of volume for use in freesurfer
upper=`fslstats rawavg -R | cut -d ' ' -f2-`
 echo "upper intensity value is " $upper 

pwd

# ###conform images to isometric space if not already isometric
echo "###determining if image isometric. If not, resample to lowest dimension specified in header######"
#### we do this here to ensure that segmentations are performed at maximum resolution. 
#### however freesurfer works best on isometric data. So here we check and convert to isometric at native resolution,


echo "###### FILLING  WM #######"

fslmaths rawavg -div $upper -mul 150 nu -odt int ###original. commented out for carmel 

 # fslmaths brainmask -div $upper -mul 300 nu -odt int #edited for carmel


 fslmaths nu -mas ${wm_seg} nu_wm



  fslmaths ${wm_seg} -add sub_cort -bin wm+SC
  fslmaths nu -mas wm+SC wm+SC_sub


  fslmaths ${wm_seg} -mul 110 wm_110

  fslmaths wm+SC -bin -mul 110 wm_110+SC

 fslmaths nu -sub nu_wm -add wm_110 brain -odt int
 
 fslmaths nu -sub wm+SC_sub -add wm_110+SC brainmask -odt int


 echo "############# creating WM images for tesselation ###########"

 ### create WM image with sub_c intensity differences #####

 echo "######### filling WM ########"
 fslmaths  ${wm_seg} -sub sub_cort wm_nosubc
 fslmaths wm_nosubc -mul 110 wm_nosubc 
 fslmaths sub_cort -mul 250 sub_cort250
 fslmaths wm_nosubc -add sub_cort250 wm


fslmaths ${wm_seg} -sub non_cort -thr 0 -bin  wm_pre_fill


fslmaths wm_pre_fill -add sub_cort250  -bin  wm_pre_fill

 fslmaths wm_pre_fill -fillh wm_pre_fill



########## fill left and right or only one side depnding on input

 for hemi in "${side[@]}";do
    if [[ ${hemi} == "left" ]];then
      echo $FSLDIR/bin/fslmaths wm_pre_fill -mas ${hemi}_hem -mul 255 wm_${hemi}
      $FSLDIR/bin/fslmaths wm_pre_fill -mas ${hemi}_hem -mul 255 wm_${hemi}
    else
      if [[ ${hemi} == "right" ]];then
        echo $FSLDIR/bin/fslmaths wm_pre_fill -mas right_hem -mul 127 wm_${hemi}
        $FSLDIR/bin/fslmaths wm_pre_fill -mas ${hemi}_hem -mul 127 wm_${hemi}
      fi
    fi
done


echo "FILLING THIS SIDE " 
echo "${side[@]}"

#### fill depending on if both sides or a single side are selected. 
if [[ "${#side[@]}" -eq 2 ]];then 
  $FSLDIR/bin/fslmaths wm_left -add wm_right filled
else
  echo  "${side[@]}"
  if [[ "${side[@]}" == left ]];then 
    $FSLDIR/bin/fslmaths wm_left -mul 0 wm_right 
    $FSLDIR/bin/fslmaths wm_left -add wm_right filled
    rm wm_right.nii.gz
  fi

  if [[ "${side[@]}" == right ]];then 
    $FSLDIR/bin/fslmaths wm_right -mul 0 wm_left 
    $FSLDIR/bin/fslmaths wm_right -add wm_left filled
    rm wm_left.nii.gz
  fi
fi

#### make sure the surface transform matches. i.e insert the identity transform here just incase

cp $FSLDIR/etc/flirtsch/ident.mat ./transforms/std2str.mat
cp $FSLDIR/etc/flirtsch/ident.mat ./transforms/str2std.mat

lta_convert --infsl $FSLDIR/etc/flirtsch/ident.mat  --outlta ${mri_dir}/transforms/talairach.lta --src ${mri_dir}/brain.nii.gz --trg ${mri_dir}/brain.nii.gz
lta_convert --infsl $FSLDIR/etc/flirtsch/ident.mat  --outmni ${mri_dir}/transforms/talairach.xfm --src ${mri_dir}/brain.nii.gz --trg ${mri_dir}/brain.nii.gz


####### insert the subcortex as 250 in the brain image 

$FSLDIR/bin/fslmaths  brain -mas sub_cort brain_rm_sc
$FSLDIR/bin/fslmaths  brain -sub brain_rm_sc -add sub_cort250 brain_SC250
$FSLDIR/bin/imrm brain_rm_sc


echo "######final conversion for surface generation######"

for hemi in "${side[@]}";do
  $FSLDIR/bin/fslmaths brain_SC250 -mas ${hemi}_hem ${hemi}_brain
  if [[ ${hemi} == "left" ]];then 
    mri_convert left_brain.nii.gz  lh.brain.finalsurfs.mgz
  fi
  if [[ ${hemi} == "right" ]];then 
    mri_convert right_brain.nii.gz  rh.brain.finalsurfs.mgz
  fi

done

 mri_convert brain.nii.gz  brain.mgz
 mri_convert brain.nii.gz  orig.mgz
 mri_convert brainmask.nii.gz brainmask.mgz   ###determining if image isometric.gz  brainmask.mgz
 mri_convert brain.nii.gz  brain.finalsurfs.mgz
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
