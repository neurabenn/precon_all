# precon_all
precon_all surface pipline

precon_all is an animal surface generation pipeline that can be easily adapted to work with multiple species. 
The curent example we'l use is the pig as it's what the pipeline has been used for the most. 

For comments and questions email **r.austinbenn@gmail.com**

First clone the directory into wherever you'd like. Add a path variable pointing to the cloned precon_all directory and name it $PCP_PATH

In order to run the pipeline simply type in the terminal surfing_safari.sh -i <my_T1.nii.gz> -r precon_all

In order to customize the pipeline you'll need to create a new directory for each new animal you wish to run the pipeline in.
The current example is $PCP_PATH/standards/pig

To add an animal simply mkdir $PCP_PATH/standards/<your_animal>

Once inside the $PCP_PATH/standards/<your_animal> you will need several key images and folders. 

Specifically you'll need the following folders:

$PCP_PATH/standards/<your_animal>/extraction

  The extraction folder contains:
  
    A whole head T1 template named: <your_animal>_temp.nii.gz 
    A brain mask aptly named: brain_mask.nii.gz 
    
    A brain extracted T1 template named: <animal>_brain.nii.gz
    
    (The pipeline has only been tested for population templates. Single subject templates could also work in theory)
    
    
You'll also need a a folder titles $PCP_PATH/standards/<your_animal>/fill
  
  The fill folder contains:
  
    A left and right hemisphere mask named: left_hem.nii.gz right_hem.nii.gz
    
    A subcortical structure mask named: sub_cort.nii.gz 
    
    A brain stem and cerebellar mask named: non_cort.nii.gz 
    
Finally you have the option to make a segmentation priors folder titled: $PCP_PATH/standards/<your_animal>/seg_priors
  
  This folder enables the use of tissue priors in the segmentation. We recommend using them if possible
  
  The seg_priors folder contains:
    
    csf.nii.gz
    
    gm.nii.gz
   
    wm.nii.gz

Stay tuned for updates. We'll soon release a manual including how to generate each of the required inputs for your animal

**Update! Macaque files are now included from the NMT NIMH macaque template. **
** Editing wm_orig.nii.gz and saving it as wm_hand_edit.ni.gz will insert your manual corrections of segmentation.**

Here's the full poster explaining the pipeline: https://user-images.githubusercontent.com/9336717/59021392-fd978080-884b-11e9-8cf1-cb21b08e776b.jpg
