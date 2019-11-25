#!/usr/bin/env python

import os
import sys
import subprocess as sp
import numpy as np
import matplotlib.pyplot as plt
import nibabel as nib
from pathlib import Path
from matplotlib.colors import LinearSegmentedColormap
import argparse
fsldir=os.getenv('FSLDIR')

### get arguments and parse them
parser = argparse.ArgumentParser(description='Generate png slices of statistical images in a specified space',usage='gen_figure.py -a < my anat> -m <my mask> ',epilog=("Example usage: "+"gen_figure.py -a anat.nii.gz -m mask.nii.gz -l alt.nii.gz"),add_help=False)
if len(sys.argv) < 2:
    parser.print_help()
    sys.exit(1)

req_grp = parser.add_argument_group(title='Required arguments')
req_grp.add_argument('-a','--anat',type=str,metavar='',required=True,help='Anatomical Image aligned to mask space. Default is to sample images here for png output')
req_grp.add_argument('-m','--mask',type=str,metavar='',required=True,help='Statistical or stat image to sample for output PNG file')

#parser.add_argument('-a','--anat',type=str,metavar='',required=True,help='Anatomical Image aligned to mask space. Default is to sample images here for png output')
#parser.add_argument('-m','--mask',type=str,metavar='',required=True,help='Statistical or stat image to sample for output PNG file')
op_grp= parser.add_argument_group(title='Optional arguments')
op_grp.add_argument('-l','--alt',type=str,metavar='',help='Resample data to alternate reference image for slice represenation. Generally used in animal studies,args.alt')
op_grp.add_argument('-t','--thr',type=float,metavar='',help='Minimum threshold applied to statistical image. between 0-1. Default is 0.2')
#op_grp.add_argument('-o','--out',type=str,metavar='',help='Specify output directory. Defualt is cwd/figures')
op_grp.add_argument("-h", "--help", action="help", help="show this help message and exit")
args=parser.parse_args()

#get those arguments into variables
anat=args.anat
mask=args.mask
alt=args.alt
thresh=args.thr
#out=out.grp
### here's our big if

#### load them niftis in
anat_obj=nib.load(anat,mmap=False)
anat_dat = anat_obj.get_data().astype(float)
anat_geom=anat_dat.shape
#### load mask or statistical map into 
mask_obj=nib.load(mask,mmap=False)
mask_dat= mask_obj.get_data().astype(float)
mask_geom=mask_dat.shape
print("the size of the standard image is", anat_geom)

print("the size of the mask image is", mask_geom)

if thresh !=None:
	thresh=thresh
else:
	thresh=0.2

if alt != None:
	print('alt is present')
	alt_ref=alt
	###get basename here 
	anat_base=os.path.basename(anat)
	anat_obj=sp.run([fsldir+'/bin/remove_ext' ,anat_base],stdout=sp.PIPE)
	anat_name=anat_obj.stdout.decode('utf-8')
	#### get basename here
	alt_base=os.path.basename(alt_ref)
	alt_obj=sp.run([fsldir+'/bin/remove_ext' ,alt_base],stdout=sp.PIPE)
	alt_name=alt_obj.stdout.decode('utf-8')
	out_flirt="""{orig}_2_{alt}.mat"""
	out_flirt=out_flirt.format(orig=anat_name,alt=alt_name)
	out_flirt=out_flirt.split('\n')
	out_mat=''
	for i in out_flirt:
		out_mat += i
	print(out_mat)
	flirt_cmd="""/usr/local/fsl/bin/flirt -in {orig} -ref {targ} -omat {out_m} """
	flirt_cmd=flirt_cmd.format(orig=anat, targ=alt_ref, out_m=out_mat)
	mask_reg="""/usr/local/fsl/bin/flirt -in {mask} -ref {targ} -applyxfm -init {out_m} -interp nearestneighbour -out rs_{mask}"""
	mask_regcmd=mask_reg.format(mask=mask, targ=alt_ref, out_m=out_mat)
	

	if  Path(out_mat).exists():
		print("already flirted")
		mask_new=[]
		#maskreg_cmd=mask_regcmd.split('\n')
		print(mask_regcmd)
		#for cmd  in mask_regcmd:
		print('Running command: ', mask_regcmd)
		mask_obj = sp.run(mask_regcmd.split(), stdout = sp.PIPE)
		mask_new.append(mask_obj.stdout.decode('utf-8'))
		mask='rs_{mask_name}'.format(mask_name=mask)
		print(mask)
		print(alt_ref)
		
		
	else:
		print("let's get flirty")
		flr=[]
		flirt_cmd=flirt_cmd.split('\n')
		for cmd  in flirt_cmd:
			print('Running command: ', cmd)
			flr_obj = sp.run(cmd.split(), stdout = sp.PIPE)
			flr.append(flr_obj.stdout.decode('utf-8'))
			mask_new=[]
		#maskreg_cmd=mask_regcmd.split('\n')
			print(mask_regcmd)
		#for cmd  in mask_regcmd:
			print('Running command: ', mask_regcmd)
			mask_obj = sp.run(mask_regcmd.split(), stdout = sp.PIPE)
			mask_new.append(mask_obj.stdout.decode('utf-8'))
			mask='rs_{mask_name}'.format(mask_name=mask)


print(thresh)
def generate_overlay_figure(T1,mask,thr):
	#### Get COG coordinates
	cog_obj=sp.run([fsldir+'/bin/fslstats',mask,'-x'],stdout=sp.PIPE)
	cog_mask = cog_obj.stdout.decode('utf-8')
	x=float(cog_mask.split()[0])
	x=int(x)
	y=float(cog_mask.split()[1])
	y=int(y)
	z=float(cog_mask.split()[2])
	z=int(z)
	#print("The mask center of gravity is ",x,y,z)
	scale_obj=sp.run([fsldir+'/bin/fslstats',mask,'-R'],stdout=sp.PIPE)
	scale=scale_obj.stdout.decode('utf-8')
	mini=float(scale.split()[0])
	maxi=float(scale.split()[1])
	if maxi==1:
	    maxi=10
	else:
		maxi=maxi*0.9
	if mini ==0:
	    mini=1
	else:
		mini=maxi * thr
	mini=str(mini)
	maxi=str(maxi)
	#### create overlay image
	#print(fsldir+'/bin/overlay','1 1', anat, '-a', mask, str(mini), str(maxi), ' test')
	command="""/usr/local/fsl/bin/overlay 1 1 {t1} -A {roi} {low} {high}  render_{roi}"""
	command=command.format(t1=T1, roi=mask, low=mini,high=maxi)
	command=command.split('\n')
	print('Running command: ', command)

	ovr=[]
	for cmd in command:
		print('Running command: ', cmd)
		ovr_obj = sp.run(cmd.split(), stdout = sp.PIPE)
		ovr.append(ovr_obj.stdout.decode('utf-8'))
	### generate figure	
	render='render_'+mask
	rend_obj=nib.load(render,mmap=False)
	rend_dat = rend_obj.get_data().astype(float)
	print("the size of the image is", rend_dat.shape)
#generate the figure
	cdict1 = {
    'red':   ((0.0, 0.0, 0.0),
              (0.5, 1.0, 0.3),
              (1.0, 0.0, 0.0)),

    'green': ((0.0, 0.0, 0.0),
              (0.5, 1.0, 1.0),
              (1.0, 0.0, 0.0)),

    'blue':   ((0.0, 0.0, 0.0),
              (0.5, 1.0, 1.0),
              (1, 0.5, 1.0)),
         }

	black_andblue = LinearSegmentedColormap('BlackWhiteBlack', cdict1)


	x=np.rot90(rend_dat[x,:,:],1)
	y=np.rot90(rend_dat[:,y,:],1)
	z=np.rot90(rend_dat[:,:,z],1)
	#print('the aspect ratios of each image are: ')
	### calculate aspect ratios
	x_asp=(x.shape[0]/x.shape[1])
	y_asp=(y.shape[0]/y.shape[1])
	z_asp=(z.shape[0]/z.shape[1])
	x_aspnew=z_asp/x_asp
	y_aspnew=z_asp/y_asp
	#print(' X aspect ratio: ',x_asp,'\n','Y aspect ratio: ',y_asp, '\n', 'Z aspect ratio: ',z_asp)
	fig=plt.figure()
	fig.set_facecolor('black')
	plt.tight_layout()
	plt.subplot(1,3, 1)
	plt.imshow(x, cmap=black_andblue ,aspect='equal')
	plt.grid('off')
	plt.axis('off')
	plt.subplot(1,3, 2)
	plt.imshow(y, cmap=black_andblue ,aspect='equal')
	plt.grid('off')
	plt.axis('off')
	plt.subplot(1,3, 3)
	plt.imshow(z, cmap=black_andblue ,aspect='equal',vmin=10)
	plt.grid('off')
	plt.axis('off')
	fig.subplots_adjust(wspace=0.1, hspace=0.1)
	fig.subplots_adjust(left=0 ,right=1,top=1,bottom=0)
	#plt.show()
	out_name=mask.split()
	out_name=(out_name[0].split('.')[0])
	out="{name}.png"
	out=out.format(name=out_name)
	plt.savefig(out,facecolor='k',bbox_inches='tight',pad_inches=0)
	plt.close()

	####clean up files
	#os.remove(render)

print(anat)
print(mask)
print(alt)


try:
	alt_ref
	generate_overlay_figure(alt_ref,mask,thresh)
except NameError:
	print('using native space')
	print(anat)
	print(mask)
	generate_overlay_figure(anat,mask,thresh)








