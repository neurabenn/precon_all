#!/bin/bash
Usage() {
    echo " "
    echo "downsampling of surface"
    echo ""
    echo "Usage: `basename $0` [options] -s <subject_folder> -h <hemi> -v < # vertices>"
    echo ""
    echo "Compulsory Arguments "
    echo "-s <subject_folder>		: Directory output of precon_all "
  
    echo "-h <hemi>		: hemisphere designation of lh or rh of surfaces to generate" 
    echo ""
    echo "-v <# vertices> :  Minimal number of vertices which can be specified is 500. going below this will force script to exit" 
    echo "Example:  `basename $0` -i <T1.nii.gz> -r precon_all -a <pig>"
    
    exit 1
}


NC=$(echo -en '\033[0m') #NC
RED=$(echo -en '\033[00;31m') #Red for error messages
GREEN=$(echo -en '\033[00;32m')
#### variables to be set by case statement
subj=""
hemi=""
verts=""

while getopts ":s:h:v:" opt ; do 
    
	case $opt in
		s) i=1;
			subj=`echo $OPTARG`
			
				;;
		h) hemi=1;
			hemi=`echo $OPTARG`

			
			;;
    v) v=1;
      verts=`echo $OPTARG`
      ;;

		\?)
		  echo "Invalid option:  -$OPTARG" 
		  	Usage
		  	exit 1
		  	;;

	esac 
done


###3 check inputs
if [[ ! -d ${subj} ]];then echo "${RED}\n-s SUBJECT MUST BE DEFINED ${NC}" ; Usage; exit 1 ;fi
if [ "${hemi}" == "lh" ] || [ "${hemi}" == "rh" ] ;then echo ${hemi}; else echo "${RED}\n-h HEMISPHERE MUS BE DEFINED lh or rh ${NC}" ; exit 1 ;fi
if [[ "${verts}" -lt 500 ]];then echo " "; echo " ${RED}DEFINE NUMBER OF VERTICES. Vertices should be equal to or greater than 500 ${NC}"; Usage; exit 1;fi ### check input file exists

if [[ verts -lt 1000 ]];then rd=${verts}; else rd=${verts/000}K;fi 

out=${subj}/surf_${rd}
mkdir -p ${out}
echo ${out}

wb_command -surface-create-sphere ${verts} ${out}/${hemi}.sphere_${rd}.surf.gii


if [[ "${hemi}" == "lh" ]];then wb_command -set-structure ${out}/${hemi}.sphere_${rd}.surf.gii CORTEX_LEFT;fi 
if [[ "${hemi}" == "rh" ]];then wb_command -set-structure ${out}/${hemi}.sphere_${rd}.surf.gii CORTEX_RIGHT;fi 
for srf in white graymid midthickness pial inflated;do 
    wb_command -surface-resample ${subj}/surf/${hemi}.${srf}.surf.gii ${subj}/surf/${hemi}.sphere.surf.gii \
    ${out}/${hemi}.sphere_${rd}.surf.gii BARYCENTRIC ${out}/${hemi}.${srf}.surf.gii
done


