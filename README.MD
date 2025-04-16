# precon_all
precon_all surface pipline

precon_all is an animal surface generation pipeline that can be easily adapted to work with multiple species. 
The curent example we'l use is the pig as it's what the pipeline has been used for the most. 

For comments and questions email **r.austinbenn@gmail.com**

First clone the directory into wherever you'd like. Add a path variable pointing to the cloned precon_all directory and name it $PCP_PATH

# Running precon_all on a single subject from a new species

Simply create these five masks:
1. A brain mask called `brain_mask.nii.gz`
2. A left hemishpere mask named `left_hem.nii.gz`
3. A right hemishpere mask named `right_hem.nii.gz`
4. A subcortical mask which covers the corpus callosum and everything beneath it as well as the ventricles. 
This is the area that will be filled in by the medial wall. call it `sub_cort.nii.gz`
5. A non cortical mask which includes everything you wish to exclude from the final surface. name it `non_cort.nii.gz`

Then place all these masks in a folder named `masks` in the working directory where your image is.

Then to run the pipeline like this  `surfing_safari.sh -i <my_T1.nii.gz> -r precon_all -a masks`

# Setting up precon_all for high throughput processing with a standard template

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
        
    
You'll also need a a folder titles $PCP_PATH/standards/<your_animal>/fill
  
  The fill folder contains:
  
    A left and right hemisphere mask named: left_hem.nii.gz right_hem.nii.gz
    
    A subcortical structure mask named: sub_cort.nii.gz 
    
    A brain stem and cerebellar mask named: non_cort.nii.gz 
  
After all this is done, run the pipeline by typing 
`surfing_safari.sh -i <my_T1.nii.gz> -r precon_all -a <your_animal>`

Finally you have the option to make a segmentation priors folder titled: $PCP_PATH/standards/<your_animal>/seg_priors
  
  This folder enables the use of tissue priors in the segmentation. We recommend using them if possible
  
  The seg_priors folder contains:
    
    csf.nii.gz
    
    gm.nii.gz
   
    wm.nii.gz
**Segmentation priors are optional. The pipeline will run without them, though you may need to perform more manual intervention posthoc**

# Correcting white and pial surfaces
Precon_all is built on freesurfer. To edit a surface simply edit the `wm.nii.gz` and save it in the `/mri/` folder of your subject as `wm_hand_edit.nii.gz`. This is the same process used in human Freesurfer to [correct pial surfaces](https://surfer.nmr.mgh.harvard.edu/fswiki/FsTutorial/PialEditsV6.0) except the file needs to be a nifti. 

# Other options when running
- If you are running this on a brain that's already been extracted pass the `-n` flag
- If you want to run segmentation with ANTs instead of FAST pass the `-s` flag
- If you want to run on only the left hemisphere or only have left heisphere data pass the flad `-L`
- Similarly for the right pass the `-R` flag
- You can down sample the surfaces to a certain icosahedral sphere by passing the flag `-v nvertices` 
- You can change the segmentation threshold for white matter with the `-t` flag. 

# Precon_all modules 
 - precon_all reconstructs the cortical surface from a single whole body image.
 - precon_1 Only performs brain extraction i.e step 1
 - precon_2 performs steps Denoising, Segmentation, WM fill and generates surfaces
 - precon_3 performs only WM filling and Generates surfaces
 - precon_4 will downsample the output of a previous precon_all run. `-v` flag is mandatory.
 - precon_art meant for art projects or figures in which the non_cort mask is included. Only run after precon_all has been succesffuly run. Precon art is not meant to give any statistics or information on the surface and is afor visualization purposes only

 # Setting up the precon_all docker container
 Precon_all can be run through a docker container as well as on linux subsystem in windows.
 To set this up, first edit line 317 of the `precon_alldockerfile` to point to your local path to your freesurfer license.
 Then simply run the `precon_all_docker.sh` script.

