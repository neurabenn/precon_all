#!/usr/bin/env python

import os,sys,argparse,re
import glob as gl
import numpy as np
fsldir=os.getenv('FSLDIR')

#### quick function to check the difference between two transformation matrices. 
#### can be used to decide wheter to stick with 6dof or bbr for example. 

def check_translations(A,B,thr):
	# load the fsl output matrices as text files even though they end in .mat  



	###Distance =|(fnorm(𝐴)−fnorm(𝐵))| where fnorm = sq root of sum of squares of all singular values.

	thr=float(thr)
	A=str(A)
	B=str(B)
	A=open(A,'r')
	a=A.read()
	A.close()

	B=open(B,'r')

	b=B.read()
	B.close()

	a=np.asarray(a.split( ) ,dtype=float)
	a=np.square(a)
	a=sum(a)
	a=a**0.5
	
	# a=a.reshape(4,4)
	b=np.asarray(b.split( ), dtype=float)
	b=np.square(b)
	b=sum(b)
	b=b**0.5
	# print(abs(a-b))
	change=abs(a-b)
	
	if change < thr:
		return(True)

	else:
		return(False)

check_translations(sys.argv[1],sys.argv[2],sys.argv[3])

print(check_translations(sys.argv[1],sys.argv[2],sys.argv[3]))