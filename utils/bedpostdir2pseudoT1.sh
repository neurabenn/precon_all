usage() {
    cat <<EOF
Usage: $(basename "$0") <bedpost_dir> <prefix> [nsqrt]

  bedpost_dir   completed bedpostx directory
  prefix        name of output file
  nsqrt         number of times to square root for contrast adjustment (default: 1)

  Script takes a bedpost directory as input and outputs a fake T1 image. 

EOF
    exit 1
}

[[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]] && usage
(( $# == 2 || $# == 3 )) || { echo "ERROR: expected 2 or 3 arguments, got $#" >&2; usage; }

bedpost_dir=$1
prefix=$2
nsqrt=${3:-1}


$FSLDIR/bin/fslmaths ${bedpost_dir}/mean_f1samples.nii.gz -sqr f1_sqr
$FSLDIR/bin/fslmaths ${bedpost_dir}/mean_f2samples.nii.gz -sqr f2_sqr

sqrt_flags=()
for ((i=0; i<nsqrt; i++)); do sqrt_flags+=(-sqrt); done

"$FSLDIR"/bin/fslmaths f1_sqr -add f2_sqr "${sqrt_flags[@]}" "${prefix}.nii.gz"

rm f1_sqr.nii.gz f2_sqr.nii.gz