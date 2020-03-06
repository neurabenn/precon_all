#!/usr/bin/env python

import os
import sys
import subprocess as sp
import numpy as np
import matplotlib.pyplot as plt
import nibabel as nib
from pathlib import Path
from matplotlib.gridspec import GridSpec
from matplotlib.colors import LinearSegmentedColormap
import argparse
fsldir=os.getenv('FSLDIR')

### get arguments and parse them
parser = argparse.ArgumentParser(description='Generate png slices of anatomical image at center of gravity',usage='quick_look.py -a < my anat> -m <my mask> ',epilog=("Example usage: "+"quick_look.py -a anat.nii.gz "),add_help=False)
if len(sys.argv) < 1:
    parser.print_help()
    sys.exit(1)

req_grp = parser.add_argument_group(title='Required arguments')
req_grp.add_argument('-a','--anat',type=str,metavar='',required=True,help='Anatomical Image aligned to mask space. Default is to sample images here for png output')
req_grp.add_argument('-m','--mask',type=str,metavar='',required=True,help='Statistical or stat image to sample for output PNG file')

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
#### load them niftis in
anat_obj=nib.load(anat,mmap=False)
anat_dat = anat_obj.get_data().astype(float)
anat_geom=anat_dat.shape
#### load mask or statistical map into 
mask_obj=nib.load(mask,mmap=False)
mask_dat= mask_obj.get_data().astype(float)
mask_geom=mask_dat.shape
mask_name=os.path.basename(mask)
print(mask_name)

#### set a low default theshold. makes sense as this is for tractograph results
if thresh !=None:
	thresh=thresh
	print(f'the threshold being applied is {thresh}')
else:
	thresh=0.005
	print(f'the threshold being applied is {thresh}')

if alt != None:
	print('alt is present')
	#### create directory to hold resliced niftis
	Path(f'{os.path.dirname(mask)}/reslice/').mkdir(parents=True, exist_ok=True)
	rs_dir=f'{os.path.dirname(mask)}/reslice/'
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
	print(mask)
	flirt_cmd="""/usr/local/fsl/bin/flirt -in {orig} -ref {targ} -omat {out_m} """
	flirt_cmd=flirt_cmd.format(orig=anat, targ=alt_ref, out_m=out_mat)
	mask_reg="""/usr/local/fsl/bin/flirt -in {mask} -ref {targ} -applyxfm -init {out_m} -interp nearestneighbour -out {rs_dir}/rs_{mask_name}"""

	mask_regcmd=mask_reg.format(mask=mask, targ=alt_ref, out_m=out_mat,rs_dir=rs_dir,mask_name=mask_name)
	
	print(mask_regcmd)
	if  Path(out_mat).exists():
		print("already flirted")
		mask_new=[]
		#maskreg_cmd=mask_regcmd.split('\n')
		print(mask_regcmd)
		#for cmd  in mask_regcmd:
		print('Running command: ', mask_regcmd)
		mask_obj = sp.run(mask_regcmd.split(), stdout = sp.PIPE)
		mask_new.append(mask_obj.stdout.decode('utf-8'))
		mask='rs_{mask_name}'.format(mask_name=mask_name)
		mask=f'{rs_dir}/rs_{mask_name}'
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

def generate_glass_brain(T1,mask):
	### reload images 	
	mask_obj=nib.load(mask,mmap=False)
	mask_dat = mask_obj.get_data().astype(float)




	### make the glass brain image
	binn=[]
	bin_mask="""/usr/local/fsl/bin/fslmaths {T1} -bin -dilM -edge -bin glass_brain """
	bin_msk_cmd=bin_mask.format(T1=T1)
	bin_obj = sp.run(bin_msk_cmd.split(), stdout = sp.PIPE)
	binn.append(bin_obj.stdout.decode('utf-8'))
	GB_obj=nib.load('./glass_brain.nii.gz',mmap=False)
	GB_dat = GB_obj.get_data().astype(float)

	print(GB_dat.shape)
	print(mask_dat.shape)



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
	print(x)
	print(y)
	print(z)
	print("################UP TO HERE#############")

	x1=np.rot90(GB_dat[int(x),:,:],1)
	y1=np.rot90(GB_dat[:,int(y),:],1)
	z1=np.rot90(GB_dat[:,:,int(z)],1)


	x2=np.rot90(mask_dat[int(x),:,:],1)
	y2=np.rot90(mask_dat[:,int(y),:],1)
	z2=np.rot90(mask_dat[:,:,int(z)],1)

	print('the aspect ratios of each image are: ')
	### calculate aspect ratios
	x_asp=(x1.shape[0]/x1.shape[1])
	y_asp=(y1.shape[0]/y1.shape[1])
	z_asp=(z1.shape[0]/z1.shape[1])
	x_aspnew=z_asp/x_asp
	y_aspnew=z_asp/y_asp
	print(' X aspect ratio: ',x_asp,'\n','Y aspect ratio: ',y_asp, '\n', 'Z aspect ratio: ',z_asp)


	fig=plt.figure(facecolor='gray')

	gs = GridSpec(nrows=2, ncols=2)


	cmap=plt.cm.autumn
	cmap.set_under(color='gray')
	plt.tight_layout()
	ax0 = fig.add_subplot(gs[0, 0])
	ax0.imshow(x2,aspect='equal',cmap=cmap,vmin=0.005)
	ax0.imshow(x1,aspect='equal',cmap=cmap,vmin=0.9,alpha=0.1)
	ax0.grid('off')
	ax0.axis('off')
	ax1 = fig.add_subplot(gs[1, 0])
	ax1.imshow(y2,aspect='equal',cmap=cmap,interpolation='none',vmin=0.005)
	ax1.imshow(y1,aspect='equal',cmap=cmap,interpolation='none',alpha=0.1,vmin=0.9)
	
	ax1.grid('off')
	ax1.axis('off')
	ax2 = fig.add_subplot(gs[:, 1])

	ax2.imshow(z2,aspect='equal',cmap=cmap,interpolation='none',vmin=0.005)
	ax2.imshow(z1,aspect='equal',cmap=cmap,interpolation='none',vmin=0.9,alpha=0.1)
	
	ax2.grid('off')
	ax2.axis('off')
	fig.subplots_adjust(wspace=0.1, hspace=0.1)
	fig.subplots_adjust(left=0 ,right=1,top=1,bottom=0)
	# plt.show()
	out_name=mask.split()
	out_name=(out_name[0].split('.')[0])
	out="{name}.png"
	out=out.format(name=out_name)
	plt.subplots_adjust(top = 1, bottom = 0, right = 1, left = 0, 
            hspace = 0, wspace = 0)
	plt.margins(0,0)
	plt.gca().xaxis.set_major_locator(plt.NullLocator())
	plt.gca().yaxis.set_major_locator(plt.NullLocator())
	plt.savefig(out,bbox_inches='tight',pad_inches=0,facecolor=fig.get_facecolor(), transparent=True)
	plt.close()

try:
	alt_ref
	print('using alt_ref')
	generate_glass_brain(alt_ref,mask)
except NameError:
	print('using native space')
	generate_glass_brain(anat,mask)


 
