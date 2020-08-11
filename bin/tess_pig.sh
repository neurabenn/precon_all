#!/bin/bash 
source $FREESURFER_HOME/SetUpFreeSurfer.sh
Usage() {
    echo " "
    echo "Usage: `basename $0` [options] -i <Subject> -h <lh or rh>"
    echo ""
    echo " Compulsory Arguments "
    echo "-s <Subject directory>                  : Directory containing preprocessed animal for surfac generation "
  
    echo "-h <?h>          			: hemisphere designationof lh or rh of surfaces to generate"
    echo " "
    echo " Optional Arguments" 
    echo " -n <7>          : Number of steps to inflate the WM during the second inflatoin. default is 7"
    echo " "
    echo "Example:  `basename $0` -i <subject_directory> -h lh  -n 7"
    
    exit 1
}

if [ $# -lt 4 ] ; then Usage; exit 0; fi #### check that command is not called empty

NC=$(echo -en '\033[0m') #NC
RED=$(echo -en '\033[00;31m') #Red for error messages



####variables to be filled via options
subj=""
hemi=""
infla=3
#### parse them options
while getopts ":s:h:a:" opt ; do 
	case $opt in
		s) 
			subj=`echo $OPTARG`
			if [ -d ${subj} ];then : ;else  echo " ${RED}CHECK INPUT FILE PATH is to a subject ${NC}"; Usage; exit 1;fi ### check input directory exists
				;;
		h) 
			hemi=`echo $OPTARG`
			#if [ ! -f ${mask} ];then echo " "; echo " ${RED}CHECK INPUT FILE PATH ${NC}"; Usage; exit 1;fi ### check input file exists
			#if [ "${mask: -4}" == ".nii" ] || [ "${mask: -7}" == ".nii.gz" ] ;then : ; else Usage; exit 1 ;fi
				;;
		a) 
			infla=`echo $OPTARG`
				;;
		\?)
		  echo "Invalid option:  -$OPTARG"

		  	Usage
		  	exit 1
		  	;;

	esac 
done

echo ${subj}
echo ${hemi}
echo ${infla}

SUBJECTS_DIR=$(echo $(cd $(dirname "${subj}") && pwd -P))/
 subj=$(basename ${subj})
 echo $SUBJECTS_DIR
 echo ${subj}
   subj_full=${SUBJECTS_DIR}${subj}/
  echo $subj_full
   mri_dir=${subj_full}mri
   surf_dir=${subj_full}surf

    cd ${mri_dir}
  pwd 
    mri_mask -T 5 brain.mgz brainmask.mgz brain.finalsurfs.mgz

     cd $surf_dir
   pwd 

 #### determine which hemisphere to reconstruct ####

 if [ ${hemi} == "lh" ];then
 echo "##### recon ${hemi} #####" 
   mri_tessellate ${mri_dir}/filled-pretess255.mgz 255 lh.orig.nofix
 fi
 if [ ${hemi} == "rh" ];then
  echo "##### recon ${hemi} #####"
   mri_tessellate ${mri_dir}/filled-pretess127.mgz 127 rh.orig.nofix
 fi 





   mris_extract_main_component ${hemi}.orig.nofix ${hemi}.orig.nofix

   mris_smooth -nw ${hemi}.orig.nofix ${hemi}.smoothwm.nofix

   mris_inflate -n 1000 -no-save-sulc ${hemi}.smoothwm.nofix ${hemi}.inflated.nofix
   mris_sphere -q -seed 1234 ${hemi}.inflated.nofix ${hemi}.qsphere.nofix
   cp ${hemi}.orig.nofix ${hemi}.orig
   cp ${hemi}.inflated.nofix ${hemi}.inflated

   cd ${SUBJECTS_DIR}
  mris_fix_topology -mgz -sphere qsphere.nofix -ga -seed 1234 ${subj} ${hemi}
  cd $surf_dir
   mris_euler_number ${hemi}.orig cd
  mris_remove_intersection ${hemi}.orig ${hemi}.orig

  cd ${SUBJECTS_DIR}


 mris_make_surfaces -noaseg -noaparc -mgz -T1 ${hemi}.brain.finalsurfs ${subj} ${hemi} 

 cd $surf_dir
 mris_smooth -n 3 -nw -seed 1234 ${hemi}.white ${hemi}.smoothwm
  mris_inflate  -dist .01 -f .001  -n ${infla}  ${hemi}.smoothwm ${hemi}.inflated 
  mris_curvature -thresh .999 -n -a 5 -w -distances 10 10 ${hemi}.inflated

 cd $subj_full
 mris_curvature_stats -m --writeCurvatureFiles -G -o ${hemi}.curv.stats -F smoothwm ${subj} ${hemi} curv sulc


 cd $surf_dir
 mris_sphere ${hemi}.inflated ${hemi}.sphere

 #### calculate volume and mid thickness
 mris_calc -o ${hemi}.area.mid ${hemi}.area add ${hemi}.area.pial
 mris_calc -o ${hemi}.area.mid ${hemi}.area.mid div 2
 mris_calc -o ${hemi}.volume ${hemi}.area.mid mul ${hemi}.thickness

mris_expand -thickness ${hemi}.white 0.5 ${hemi}.graymid 

for surf in white pial graymid inflated;do 
    mris_convert --to-scanner ${hemi}.${surf} ${hemi}.${surf}.surf.gii
done

mris_convert ${hemi}.sphere  ${hemi}.sphere.surf.gii

wb_command  -surface-average ${hemi}.midthickness.surf.gii -surf ${hemi}.white.surf.gii -surf ${hemi}.pial.surf.gii
