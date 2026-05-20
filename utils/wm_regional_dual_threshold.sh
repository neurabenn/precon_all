#!/bin/bash
### apply dual threshold to a WM probability/posterior image
### strict threshold outside a region mask, lenient inside it
### use to rescue under-called WM in difficult regions (e.g. temporal pole)
### without over-claiming WM elsewhere
### output goes to <precon_dir>/mri/wm_hand_edit.nii.gz
 
usage() {
    cat <<EOF
Usage: $(basename "$0") <wm_seg> <main_thr> <std_region_mask> <region_thr>
 
  wm_seg           WM probability image inside a precon_all seg/ directory
                   (e.g. SegmentationPosteriors3.nii.gz or seg_pve_2.nii.gz)
  main_thr         strict threshold applied outside the region (e.g. 0.5)
  std_region_mask  binary mask in standard space defining the lenient region
                   (e.g. hand-drawn temporal pole mask on the template)
  region_thr       lenient threshold applied inside the region (e.g. 0.3)
 
Expects under the precon_all dir:
  ./mri/rawavg.nii.gz
  ./mri/transforms/std2str_warp.nii.gz
  ./rawavg_brain_mask.nii.gz
EOF
    exit 1
}
 
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then usage; fi
if [ $# -lt 4 ]; then echo "ERROR: missing arguments"; usage; fi
 

wm_seg=$1 ### segmentation pve or posterior to threshold
main_thr=$2
std_region_mask=$3
region_thr=$4

precon_dir=$(dirname $(dirname ${wm_seg}))
wm_seg=$(basename ${wm_seg})
cd ${precon_dir}

applywarp -i ${std_region_mask} -r ./mri/rawavg.nii.gz \
-w ./mri/transforms/std2str_warp.nii.gz --interp=nn -o ./seg/str_region_mask.nii.gz

fslmaths ./seg/str_region_mask.nii.gz -dilM ./seg/str_region_mask.nii.gz

fslmaths ./rawavg_brain_mask.nii.gz -sub ./seg/str_region_mask.nii.gz ./seg/tmp_mask

fslmaths ./seg/${wm_seg} -mas ./seg/tmp_mask.nii.gz -thr ${main_thr} -bin ./seg/norm_wm



fslmaths ./seg/${wm_seg} -mas ./seg/str_region_mask.nii.gz -thr ${region_thr} -bin ./seg/problem_wm

cp ./mri/wm_orig.nii.gz ./mri/wm_orig_global_thr.nii.gz 

fslmaths ./seg/problem_wm -add ./seg/norm_wm -bin ./mri/wm_hand_edit
 
# rm  ./seg/problem_wm.nii.gz ./seg/norm_wm.nii.gz ./seg/tmp_mask.nii.gz ./seg/str_region_mask.nii.gz