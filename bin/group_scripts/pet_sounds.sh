#!/bin/bash
###### the recommended input for this script is the output of precon_all run on your volumetric template. 

source $FREESURFER_HOME/SetUpFreeSurfer.sh
### where the template is an indidivual subject folder of surfaces
### group is a .txt file of all the subject folders i.e. the precon_all output directory of individuals
temp=$1
group=$2
ico=$3
#### first we'll change the dummy tailarach transforms to be a linear registration to the template subject


ref=${temp}/mri/brain.nii.gz




	echo "prepping transforms to make average surface"
for subj in $(cat ${group});do 
	tdir=${subj}/mri/transforms/
	if [ -d "${tdir}/precon_all" ]; then
	    	echo "registration copies already done"
	else
		mkdir  ${tdir}/precon_all
		
		echo "registering" ${subj} "to" ${temp}

		if [ ! -d "${subj}/label" ]; then
			$PCP_PATH/bin/cortex_labelgen.sh -s ${subj}
		fi

		#### copy the old transforms to a precon_all folder. 
		#### you'll want to use this if you need to rerun an individual surface again
		files=`ls ${tdir}/*`

		#### change cp to mv before publishing
		cp ${files} ${tdir}/precon_all

		echo "#### running flirt registration ####"
		img=${subj}/mri/brain.nii.gz
		echo $img

		$FSLDIR/bin/flirt -in ${img} -ref ${ref} -dof 12 -searchrz -180 180 -searchry -180 180 -searchrz -180 180 -omat ${tdir}/str2temp.mat

		echo "### converting mats to FS tailarach mats ###"

		lta_convert --infsl ${tdir}/str2temp.mat  --outlta ${tdir}/talairach.lta --src ${img} --trg ${ref}
		lta_convert --infsl ${tdir}/str2temp.mat  --outmni ${tdir}/talairach.xfm --src ${img} --trg ${ref}
	fi
done



# ## make the templates i.e. do the surface registrations #### 
# ## add path later. will eventuall be $PCP_PATH/bin/something

# echo "Here's la chicha.... this part can take a while "
###### make this an optino to run form the command line or not
# $PCP_PATH/bin/group_scripts/make_surftemp.sh ${temp} ${group}



SUBJECTS_DIR=`pwd`
echo $SUBJECTS_DIR

# #############
# ####here we use a modified version of the actual freesurfer script make_average_surfaces
# #### first well copy the script from the precon_all directory 
# #### then we insert the template subjects brain into the copy as mni305.mgz 
# #### finally we'll use the rest of the script unaltered except for that we'll only use it to generate the average surfaces
# #### in order to get surface stats we need cortex labels for the average brain. as of right now that requires manual intervention

name=$(basename ${temp})
echo ${name}
### get the surface generation script out. 
cp $PCP_PATH/bin/group_scripts/make_average_surface_precon `pwd`/make_average_surface_precon_${name}
file=`pwd`/make_average_surface_precon_${name}

# # ##### need to write a function which will let us determine the correct ico for each animal. i.e. closest to waht the raw surface has. 
# # ##### for example pigs only have around 15K vertices. ico 5 is appropriate for them.
sed -i .bak "s:mni305 = /Volumes/brain/template_surfs/average/mri/mni305.cor.mgz:mni305 = `pwd`/${ref/.nii.gz/.mgz}:g" ${file}
subject_list=$(cat ${group} | tr '\n' ' ')


# # ## make the average surfaces. here we use the FS script we modified with sed from earlier. 

echo "${file} --no-annot --lh  --ico ${ico} --out avg_${name} --subjects ${subject_list}"  |bash

echo "${file} --no-annot --rh  --ico ${ico} --out avg_${name} --subjects ${subject_list}"  |bash

x=0
mkdir -p avg_${name}/lh_labels/
mkdir -p avg_${name}/rh_labels/
mkdir -p avg_${name}/lh_subc/
mkdir -p avg_${name}/rh_subc/

for itr in $(cat ${group});do 
	x=$(echo "${x}+1"|bc)
	echo ${itr}
	for hemi in lh rh;do 
		mri_label2label --srclabel ${itr}/label/${hemi}.cortex.label --srcsubject ${itr} \
		--trglabel avg_${name}/${hemi}_labels/${hemi}.cortex${x}.label --trgsubject avg_${name} --hemi ${hemi} --regmethod surface

	
		mri_label2label --srclabel ${itr}/label/${hemi}.subcortex.label --srcsubject ${itr} \
		--trglabel avg_${name}/${hemi}_subc/${hemi}.subcortex${x}.label --trgsubject avg_${name} --hemi ${hemi} --regmethod surface
	done 
done

mri_mergelabels -d avg_${name}/lh_labels/ -o avg_${name}/label/lh.cortex.label
# # 
mri_mergelabels -d avg_${name}/rh_labels/ -o avg_${name}/label/rh.cortex.label

mri_mergelabels -d avg_${name}/lh_subc/ -o avg_${name}/label/lh.subcortex.label
# # 
mri_mergelabels -d avg_${name}/rh_subc/ -o avg_${name}/label/rh.subcortex.label

rm -r avg_${name}/rh_labels/
rm -r avg_${name}/lh_labels/
rm -r avg_${name}/rh_subc/
rm -r avg_${name}/rh_subc/


# # ########### now that we have cortex labels let's rerun the surface generation removing the block on the stats part
# # # ####### first remove the line with the exit code 
sed -i.bak -e '294d' ${file}

#### add an option to only run the final stats. ideally after labels have been hand edited 
# # # #### run it again 

echo "${file} --no-annot --lh  --ico ${ico} --out avg_${name} --force  --subjects ${subject_list}"  |bash
echo "${file} --no-annot --rh  --ico ${ico} --out avg_${name} --force --subjects ${subject_list}"  |bash


