pwd

Usage() {
    echo " "
    echo "fMRI preprocessing pipeline following at least precon_1 brain extraction of preclinical data"
    echo ""
    echo "Usage: `basename $0` [options] -i <T1.nii.gz> -r <processes to run>"
    echo ""
    echo "Compulsory Arguments "
    echo "-s <Subject directory>		: Directory containing preprocessed animal for surfac generation "
  
    echo "-r < anat.nii.gz >		: name of non brain extracted image. A brain mask and extracted brain are expected in the same directory. " 
    echo ""
    echo "-e <epi.nii.gz> functional data set"
    echo "Optional Arguments" 
    echo " -f <whole body fieldmap image> must already be in units of rad/s.   "
    echo " -m <if f is specified than a full boy magnitude image is also expected>  "
    echo "-h     help "
    echo " "
    echo " The following steps are applied:\n 1: Motion Correction \n 2: Epi Undistortion  \n 3: Bandpass filtering \n 4: melodic and \n FIX 5: Registration"
    echo " "
    echo ""
    echo "Example:  `basename $0` -s <subject> -r anat.nii.gz -a <pig> -f <fieldmap.nii.gz> -m <magnitude image> "
    
    exit 1
}


NC=$(echo '\033[0m') #NC
RED=$(echo  '\033[00;31m') #Red for error messages
GREEN=$(echo  '\033[00;32m')
#### variables to be set by case statement
subj=""
anat=""
animal=""
fmap=""
mag=""
help=""

while getopts ":s:r:e:f:m:h" opt ; do 
	case $opt in
		s) s=1;
			subj=`echo $OPTARG`
				;;
		r) r=1;
            anat=`echo $OPTARG`
			;;
        e) e=1;
            epi=`echo $OPTARG`
            ;;    
    f)
        fmap=`echo $OPTARG`
        ;;
    m)
        mag=`echo $OPTARG`    
        ;;
		h) h=1;
			steps=`echo $OPTARG`
			if [ ${h} -lt 1 ];then : ; else: echo "${RED} insert help text here ${NC}"; Usage; exit 1;fi #### work on this later. not top priority this minute
			;;	
		\?)
		  echo "Invalid option:  -$OPTARG" 

		  	Usage
		  	exit 1
		  	;;

	esac 
done

#### check inputs are valid#########
if [[ ${h} -eq 1 ]];then echo "${RED}\n INSERT HELP STATEMENT ${NC}" ; Usage; exit 1 ;fi
if [[ ${s} -lt 1 ]];then echo "${RED}\n-s is a compulsory Argument${NC}" ; Usage; exit 1 ;fi
if [[ ${r} -lt 1 ]];then echo "${RED}\n-r is a compulsory Argument${NC}" ; Usage; exit 1 ;fi
if [[ ${e} -lt 1 ]];then echo "${RED}\n-e is a compulsory Argument${NC}" ; Usage; exit 1 ;fi

ruta=`pwd`
subj=${ruta}/${subj}
anat=${ruta}/${anat}
epi=${ruta}/${epi}

###### move to the subject directory####
echo ${epi}

out=`basename $epi` 

out=${ruta}/$(basename ${subj})/${out/.nii.gz/.prefeat}
##### copy files and generate brain mask ####
echo ${out}
mkdir -p ${out}
$FSLDIR/bin/imcp ${epi} ${out}
$FSLDIR/bin/imcp ${anat} ${out}
$FSLDIR/bin/imcp ${anat/.nii.gz/_brain} ${out}
$FSLDIR/bin/fslmaths ${out}/$(basename ${anat/.nii.gz/_brain}) -thr 0.1 -bin -fillh  ${out}/$(basename ${anat/.nii.gz/_brain_mask})
########## redefine variable ######## 

epi=$(basename ${epi})
anat=$(basename ${anat})
brain=${anat/.nii.gz/_brain.nii.gz}
mask=${anat/.nii.gz/_brain_mask.nii.gz}

cd ${out}
$FSLDIR/bin/imcp ${epi} prefiltered_func_data
pwd 

$FSLDIR/bin/fslmaths prefiltered_func_data -Tmean example_func

mkdir -p ${out}/reg
$FSLDIR/bin/imcp ${anat} ${out}/reg/highres_head
$FSLDIR/bin/imcp ${brain} ${out}/reg/highres
$FSLDIR/bin/imcp  ${mask} ${out}/reg/highres_mask
$FSLDIR/bin/imcp  example_func  ${out}/reg/example_func


######## initialising registrations and brain extractions ########
cd ${out}/reg
#### getting wm segmentation#####
mkdir seg
$FSLDIR/bin/fast -o seg/ highres
mv seg/_pve_2.nii.gz ./wm_seg.nii.gz
rm -r seg/
$FSLDIR/bin/fslmaths wm_seg -thr  0.5 -bin wm_seg
$FSLDIR/bin/fslmaths wm_seg -edge -thr  0.3 -bin wm_edge
#### segmentation over #######
$FSLDIR/bin/flirt -in example_func -ref highres -dof 6 -omat example_funcbody2highres.mat -out example_func_body2highres -searchrx -180 180 -searchry -180 180  -searchrz -180 180 
$FSLDIR/bin/convert_xfm -omat highres2example_func_body.mat -inverse example_funcbody2highres.mat 
$FSLDIR/bin/applywarp -i highres_mask -r example_func -o example_func_brain_mask --premat=highres2example_func_body.mat --interp=nn
$FSLDIR/bin/fslmaths example_func example_func_head
$FSLDIR/bin/fslmaths example_func -mas example_func_brain_mask example_func
$FSLDIR/bin/flirt -in example_func -ref highres -o example_func2highres_init -omat example_func2highres_init.mat -dof 6
$FSLDIR/bin/flirt -in example_func -ref highres  -init  example_func2highres_init.mat -dof 6 -cost bbr -wmseg wm_seg -schedule ${FSLDIR}/etc/flirtsch/bbr.sch -o example_func2highres.nii.gz -omat example_func2highres.mat 
$FSLDIR/bin/convert_xfm -omat highres2example_func.mat -inverse example_func2highres.mat

if [[ ${fmap} = "" ]] ;then 
    echo "no fieldmap specified. running without epi distortion correction"

else
    fmap=${ruta}/${fmap}
    echo "fieldmap is " ${fmap}
    if [[ ${mag} == "" ]];then echo "\n${RED}Magnitude image must also be specified when using fieldmaps${NC}"; Usage; exit1;fi
        echo ${fmap}
        echo ${mag}
    $FSLDIR/bin/imcp ${fmap} ${out}/reg/
    $FSLDIR/bin/imcp ${ruta}/${mag} ${out}/reg/
    cd  ${out}/reg/
    mag=$(basename ${mag})
    fmap=$(basename ${fmap})
    ##perform brain extraction for initial registrations 

    $FSLDIR/bin/flirt -in ${mag} -ref highres_head -dof 6 -omat mag2highres_init.mat  -o mag2highres_init

    $FSLDIR/bin/convert_xfm -omat  highres2mag_init.mat -inverse mag2highres_init.mat
    $FSLDIR/bin/applywarp -i highres_mask -r ${mag} --premat=highres2mag_init.mat  -o mag_brain_mask 
    ###brain extracton 
    $FSLDIR/bin/fslmaths mag_brain_mask -thr 0.3 -fillh -bin mag_brain_mask
    $FSLDIR/bin/fslmaths ${mag} -mas  mag_brain_mask  magnitude_brain
    $FSLDIR/bin/fslmaths ${fmap} -mas  mag_brain_mask fieldmap_brain 
    $FSLDIR/bin/fslmaths ${fmap} -sub `fslstats ${fmap} -P 50 ` ${fmap} ### demean fieldmap

    $FSLDIR/bin/flirt -in magnitude_brain  -ref highres -init mag2highres_init.mat -cost bbr -wmseg wm_seg.nii.gz -schedule ${FSLDIR}/etc/flirtsch/bbr.sch -dof 6 -out mag_brain2highres_brain -omat mag2highres.mat

    $FSLDIR/bin/applywarp -i ${mag} -r highres --premat=mag2highres.mat  --interp=trilinear -o mag2highres
    $FSLDIR/bin/applywarp -i ${fmap} -r highres --premat=mag2highres.mat  --interp=spline -o fmap2highres

 
    $FSLDIR/bin/convert_xfm -omat mag2example_func.mat -concat highres2example_func.mat mag2highres.mat
    $FSLDIR/bin/applywarp -i ${fmap} -r example_func --premat=mag2example_func.mat  --interp=spline -o fmap2example_func
    $FSLDIR/bin/fugue -v -i example_func_head --icorr --dwell=0.000460 --loadfmap=fmap2example_func  -u example_func_UD --unwarpdir=x-

    $FSLDIR/bin/fslmaths example_func_UD -thr 1 example_func_UD
    $FSLDIR/bin/flirt -in example_func_UD.nii.gz -ref highres -out example_func_head_UD2highres -omat example_func_UD_head2highres.mat -dof 6
    $FSLDIR/bin/convert_xfm -omat highres2example_func_UD_head.mat -inverse example_func_UD_head2highres.mat
    $FSLDIR/bin/applywarp -i highres_mask.nii.gz  -r example_func_UD --premat=highres2example_func_UD_head.mat -o example_func_UD_brain_mask
    $FSLDIR/bin/fslmaths example_func_UD_brain_mask -thr 0.9 -bin -fillh example_func_UD_brain_mask
    $FSLDIR/bin/fslmaths  example_func_UD -mas example_func_UD_brain_mask -thr 1 example_func_UD_brain
    $FSLDIR/bin/flirt -in example_func_UD_brain -ref highres.nii.gz -init example_func_UD_head2highres.mat -cost bbr -wmseg wm_seg.nii.gz  -out example_func_UD2highres -schedule /usr/local/fsl/etc/flirtsch/bbr.sch -dof 6 -omat example_func_UD2highres.mat

fi   



# ############ motion correction ##############
cd ${out}
/usr/local/fsl/bin/mcflirt -in prefiltered_func_data -out prefiltered_func_data_mcf -mats -plots -reffile example_func -rmsrel -rmsabs -spline_final

/bin/mkdir -p mc ; /bin/mv -f prefiltered_func_data_mcf.mat prefiltered_func_data_mcf.par prefiltered_func_data_mcf_abs.rms prefiltered_func_data_mcf_abs_mean.rms prefiltered_func_data_mcf_rel.rms prefiltered_func_data_mcf_rel_mean.rms mc
cd mc
/usr/local/fsl/bin/fsl_tsplot -i prefiltered_func_data_mcf.par -t 'MCFLIRT estimated rotations (radians)' -u 1 --start=1 --finish=3 -a x,y,z -w 640 -h 144 -o rot.png 

/usr/local/fsl/bin/fsl_tsplot -i prefiltered_func_data_mcf.par -t 'MCFLIRT estimated translations (mm)' -u 1 --start=4 --finish=6 -a x,y,z -w 640 -h 144 -o trans.png 

/usr/local/fsl/bin/fsl_tsplot -i prefiltered_func_data_mcf_abs.rms,prefiltered_func_data_mcf_rel.rms -t 'MCFLIRT estimated mean displacement (mm)' -u 1 -w 640 -h 144 -a absolute,relative -o disp.png 
cd ${out}

cat mc/prefiltered_func_data_mcf.mat/MAT* > mc/prefiltered_func_data_mcf.cat
$FSLDIR/bin/fugue -v -i prefiltered_func_data_mcf --icorr  --dwell=0.000460 --loadfmap=reg/fmap2example_func  -u prefiltered_func_data_mcf_UD --unwarpdir=x-

$FSLDIR/bin/fslmaths prefiltered_func_data_mcf_UD -bptf 25.0 -1  filtered_func_data ##### bandpass filtered to 100 seconds. its FWHM so TR of 2, 50 seconds means 25 as half max. 

$FSLDIR/bin/fslmaths filtered_func_data -mas reg/example_func_UD_brain_mask filtered_func_data

$FSLDIR/bin/melodic -i filtered_func_data -o filtered_func_data.ica -m reg/example_func_UD_brain_mask --report --nobet --Oall



# /usr/local/fsl/bin/applywarp -i reg/unwarp/FM_UD_fmap_mag_brain_mask -r example_func --rel --premat=reg/unwarp/FM_UD_fmap_mag_brain2str.mat --postmat=reg/highres2example_func.mat -o reg/unwarp/EF_UD_fmap_mag_brain_mask --paddingsize=1













