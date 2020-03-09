#!/bin/bash
subj=$1
T1=$2
T2=$3

odir=$(dirname ${T2})

wb_command -volume-math "clamp((T1w / T2w), 0, 100)" "$odir"/T1wDividedByT2w.nii.gz -var T1w "$T1" -var T2w "$T2" -fixnan 0
wb_command -volume-palette "$odir"/T1wDividedByT2w.nii.gz MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false

wb_command -volume-to-surface-mapping T1T2_mye/T1wDividedByT2w.nii.gz T1_mean/surf/lh.graymid.surf.gii \
./lh.mye.func.gii -myelin-style ./T1T2_mye/ribbon.nii.gz lh.thicknes.shape.gii 5
