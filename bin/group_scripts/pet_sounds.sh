#!/bin/bash
###### the recommended input for this script is the output of precon_all run on your volumetric template. 

source $FREESURFER_HOME/SetUpFreeSurfer.sh
usage() {
    cat <<EOF
Usage: $(basename "$0") [--cluster <config_file>] [--out-dir <avg_subject_name>] <template_subject_dir> <group_file> <ico_order>
Build a surface average from a set of existing precon_all subject directories,
using one subject as the volumetric/template-space reference.

Arguments:
  template_subject_dir   Path to the template subject directory.
                         This should be an existing precon_all subject directory.
                         We recommed running perocn_all on your volumetric template and using that as the template space.

  group_file             Text file containing one subject directory per line.
                         Each listed directory should be a precon_all output
                         directory for an individual subject.

  ico_order              Icosahedral order for average surface generation.
                         Example values are often 4, 5, or 6 depending on species
                         and target surface density.

Options:
  --cluster <config_file>   Pass a cluster config file through to make_surftemp.sh
  --out-dir <avg_subject_name>  Name of the average surface subject to create.
                                Default: avg_<template_subject_basename>

What the script does:
  1. Registers each subject's brain volume to the template subject brain with FLIRT.
  2. Converts the linear transform to FreeSurfer-compatible talairach files.
  3. Preserves existing transforms by copying them into mri/transforms/precon_all/.
  4. Builds left and right average surfaces using a modified
     make_average_surface_precon script.
  5. Projects individual cortex/subcortex labels onto the average subject.
  6. Merges propagated labels and reruns average-surface generation to produce
     final stats.

Requirements:
  - FREESURFER_HOME must be set
  - FSL must be installed and available
  - PCP_PATH must be set
  - The template subject must contain:
      mri/brain.nii.gz
  - Each subject in group_file should be a valid precon_all subject directory

Notes:
  - If a subject is missing label files, cortex_labelgen.sh will be run.
  - Existing transforms are copied to mri/transforms/precon_all/ before update.
  - The script edits a copied make_average_surface_precon helper script in-place.
  - Run this from the directory you want to use as SUBJECTS_DIR, since the script
    sets SUBJECTS_DIR to the current working directory.

Examples:
  $(basename "$0") /path/to/template_subject /path/to/group.txt 5
  $(basename "$0") --cluster slurm_config.txt /path/to/template_subject /path/to/group.txt 5

group_file format:
  /path/to/subj01
  /path/to/subj02
  /path/to/subj03
EOF
    exit 1
}


cluster_config=""
out_dir=""
positionals=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cluster)
            if [[ $# -lt 2 ]]; then
                echo "ERROR: --cluster requires a config file"
                usage
            fi
            cluster_config=$2
            shift 2
            ;;
        --out-dir)
            if [[ $# -lt 2 ]]; then
                echo "ERROR: --out-dir requires a name"
                usage
            fi
            out_dir=$2
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            positionals+=("$1")
            shift
            ;;
    esac
done

if [[ ${#positionals[@]} -ne 3 ]]; then
    echo "ERROR: expected 3 arguments"
    usage
fi

if [[ -n "$cluster_config" && ! -f "$cluster_config" ]]; then
    echo "ERROR: cluster config not found: $cluster_config"
    exit 1
fi

### where the template is an indidivual subject folder of surfaces
### group is a .txt file of all the subject folders i.e. the precon_all output directory of individuals
temp=${positionals[0]}
group=${positionals[1]}
ico=${positionals[2]}

if [[ -z "$out_dir" ]]; then
    out_dir="avg_$(basename "$temp")"
fi

#### first we'll change the dummy tailarach transforms to be a linear registration to the template subject

log_dir="$(pwd)/logs"
mkdir -p "${log_dir}"
log_file="${log_dir}/pet_sounds_$(date +%Y%m%d_%H%M%S).log"

on_exit() {
    status=$?
    set +x
    echo "Ended at $(date)"
    echo "Exit status: ${status}"
}

trap on_exit EXIT

exec > >(tee -a "${log_file}") 2>&1
set -x
echo "Logging to ${log_file}"
echo "Started at $(date)"
echo "Host: $(hostname)"
echo "Working directory: $(pwd)"


ref=${temp}/mri/brain.nii.gz

echo "prepping transforms to make average surface"

for subj in $(cat ${group});do 
	tdir=${subj}/mri/transforms/
	echo "registering" ${subj} "to" ${temp}
	if [ ! -d "${subj}/label" ]; then
    $PCP_PATH/bin/cortex_labelgen.sh -s ${subj}
	fi

	img=${subj}/mri/brain.nii.gz
	echo $img

  ### freesurfer will expect a tailarach transform.
  if [ ! -f "${tdir}/talairach.mat" ]; then
    $FSLDIR/bin/flirt -in ${img} -ref ${ref} -dof 12 -searchrx -180 180 -searchry -180 180 -searchrz -180 180 -omat ${tdir}/talairach.mat

    echo "### getting 'tailarach' mat ###"

      lta_convert --infsl ${tdir}/talairach.mat  --outlta ${tdir}/talairach.lta --src ${img} --trg ${ref}
      lta_convert --infsl ${tdir}/talairach.mat  --outmni ${tdir}/talairach.xfm --src ${img} --trg ${ref}
  fi
done



# ## make the templates i.e. do the surface registrations #### 
# ## add path later. will eventuall be $PCP_PATH/bin/something

# echo "Here's la chicha.... this part can take a while "
###### make this an optino to run form the command line or not
if [[ -n "$cluster_config" ]]; then
    $PCP_PATH/bin/group_scripts/make_surftemp.sh --cluster "${cluster_config}" ${temp} ${group}
else
    $PCP_PATH/bin/group_scripts/make_surftemp.sh ${temp} ${group}
fi


SUBJECTS_DIR=$(pwd)
echo "$SUBJECTS_DIR"

"$PCP_PATH/bin/group_scripts/average_surface_maker.sh" \
  --template-ref "$temp" \
  --subject-list "$group" \
  --out-dir "$out_dir" \
  --ico "$ico" \
  --stats \
  --include-ref-stats