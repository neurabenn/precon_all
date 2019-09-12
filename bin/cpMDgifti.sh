#!/bin/bash

Usage() {
	echo " $0 copies the FS surface metdata to Caret surface"
    echo " "
    echo "Usage: `basename $0` <FS.gii>  <caret.surf.gii>"
    echo ""
    echo " Compulsory Arguments "
    echo "	<FS.gii>                Gifti file in Freesurfer Convention"
    echo "	<caret.surf.gii>      Gifti file in caret convention. output of surf2surf "
    echo " "
    exit 1
}

in=${1}
new=${2}

if [ $# -lt 2 ] ; then Usage; exit 0; fi


dir=$(dirname ${in})
##### get correspinding metadata tags from first gifti 
MD1=$(cat "${in}" |grep -nr 'MetaData' )
# for i in ${MD1};do 
# 	echo "${i//[^0-9]/}"
# done
MD1=${MD1//[^0-9]/ }
startMD=$(echo ${MD1} |cut -d ' ' -f 3 )
# endMD=$(echo ${MD1} |cut -d ' ' -f 4 )

transform=$(cat "${in}" |grep -nr '</CoordinateSystemTransformMatrix>')
transform=${transform//[^0-9]/ }
endMD=$(echo ${transform} |cut -d ' ' -f 2 )
# echo ${endMD}

MD=$(sed -n "${startMD},${endMD}p" "${in}")

# mat="    <CoordinateSystemTransformMatrix>
#          <DataSpace>NIFTI_XFORM_UNKNOWN</DataSpace>
#          <TransformedSpace>NIFTI_XFORM_TALAIRACH</TransformedSpace>
#          <MatrixData>
#             1.000000 0.000000 0.000000 0.000000 
#             0.000000 1.000000 0.000000 0.000000 
#             0.000000 0.000000 1.000000 0.000000 
#             0.000000 0.000000 0.000000 1.000000 
#          </MatrixData>
#       </CoordinateSystemTransformMatrix>"

# MD=`echo "${MD}" "${mat}"`

#### get metadat insertion point from second gifti

MD2=$(cat "${new}" |grep -nr 'MetaData' )
MD2=${MD2//[^0-9]/ }
insertMD=$(echo ${MD2} |cut -d ' ' -f 3 )
echo "${MD}" >${dir}/MD.txt


# cat text.txt
var=$(sed '$!s*$*\\*' ${dir}/MD.txt)


sed -i ' ' ""${insertMD}"s*<MetaData/>*${var}*" ${new}
rm ${dir}/MD.txt