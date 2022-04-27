#!/bin/bash 

##### this script is to automate the surface generation process. A starting subject folder and list of subsequent subjects must be provided. 
##### template generation is initialized via a single subject
##### mris_register all subjects to template using sulci in fisrt iteraton. 
##### make template 1 using sphere.reg0
##### mris_register all subjects to template using curv in second iteraton
#make template 2 using sphere.reg1 
###### 3rd iteration not specified 
###### 4th iteration using curv paterns


start=$1
subjects=$2
mkdir surf_temps
out=surf_temps
SUBJECTS_DIR=$(dirname ${start})
SUBJECTS_DIR=`pwd`
echo $SUBJECTS_DIR
echo "############################## FIRST ITERATION ######################################"
mris_make_template lh sphere ${start} ${out}/lh.temp0.tif
mris_make_template rh sphere  ${start} ${out}/rh.temp0.tif
for subj in `cat $subjects`;do 
	for hemi in lh rh;do 
		echo "doing spehrical registration"
		##### edited out. this oshuld be reg0 
		mris_register ${subj}/surf/${hemi}.sphere ${out}/${hemi}.temp0.tif ${subj}/surf/${hemi}.sphere.reg0 &
	done
done
wait 
echo "####################"
echo "####################"
echo "####################"
echo "####################"
echo "####################"
mris_make_template lh sphere.reg0 `cat $subjects`  $PWD/${out}/lh.temp1.tif
mris_make_template rh sphere.reg0 `cat $subjects`  $PWD/${out}/rh.temp1.tif
# echo "############################## SECOND ITERATION ######################################"
wait 
for subj in `cat $subjects`;do 
	for hemi in lh rh;do 
		echo "pass"
		mris_register ${subj}/surf/${hemi}.sphere ${out}/${hemi}.temp1.tif ${subj}/surf/${hemi}.sphere.reg1 
	done
done


mris_make_template lh sphere.reg1 `cat $subjects`  $PWD/${out}/lh.temp2.tif
mris_make_template rh sphere.reg1 `cat $subjects`  $PWD/${out}/rh.temp2.tif

echo "############################## THIRD ITERATION ######################################"
for subj in `cat $subjects`;do 
	for hemi in lh rh;do 
		echo "pass"
		mris_register ${subj}/surf/${hemi}.sphere ${out}/${hemi}.temp2.tif ${subj}/surf/${hemi}.sphere.reg2 
	done

done
wait 

mris_make_template lh sphere.reg2 `cat $subjects`  $PWD/${out}/lh.temp3.tif
mris_make_template rh sphere.reg2 `cat $subjects`  $PWD/${out}/rh.temp3.tif

echo "############################## FOURTH ITERATION ######################################"
for subj in `cat $subjects`;do 
	for hemi in lh rh;do 
		echo "pass"
		mris_register ${subj}/surf/${hemi}.sphere ${out}/${hemi}.temp3.tif ${subj}/surf/${hemi}.sphere.reg3 
	done
done
wait 
mris_make_template lh sphere.reg3 `cat $subjects`  $PWD/${out}/lh.temp4.tif
mris_make_template rh sphere.reg3 `cat $subjects`  $PWD/${out}/rh.temp4.tif

for subj in `cat $subjects`;do 
	for hemi in lh rh;do 
		echo "pass"
		mris_register ${subj}/surf/${hemi}.sphere ${out}/${hemi}.temp4.tif ${subj}/surf/${hemi}.sphere.reg 
	done
done














