#!/bin/bash 

##### this script is to automate the surface generation process. A starting subject folder and list of subsequent subjects must be provided. 
##### template generation is initialized via a single subject
##### mris_register all subjects to template using sulci in fisrt iteraton. 
##### make template 1 using sphere.reg0
##### mris_register all subjects to template using curv in second iteraton
#make template 2 using sphere.reg1 
###### 3rd iteration not specified 
###### 4th iteration using curv paterns

usage() {
    cat <<EOF
Usage: $(basename "$0") [--cluster <config_file>] <start_subject> <subjects_file>

Arguments:
  start_subject    starting/template subject directory
  subjects_file    text file with one subject directory per line

Options:
  --cluster <config_file>   use Slurm config file
EOF
    exit 1
}

cluster=0
cluster_config=""
positionals=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cluster)
            [[ $# -ge 2 ]] || { echo "ERROR: --cluster requires a config file" >&2; usage; }
            cluster=1
            cluster_config=$2
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

if [[ ${#positionals[@]} -ne 2 ]]; then
    echo "ERROR: expected 2 arguments" >&2
    usage
fi

start=${positionals[0]}
subjects=${positionals[1]}

if [[ "$cluster" -eq 1 ]]; then
    [[ -f "$cluster_config" ]] || { echo "ERROR: cluster config not found: $cluster_config" >&2; exit 1; }

    source "$cluster_config"

    : "${SLURM_PARTITION:?cluster config must set SLURM_PARTITION}"
    : "${SLURM_TIME:?cluster config must set SLURM_TIME}"
    : "${SLURM_MEM:?cluster config must set SLURM_MEM}"
fi

submit_worklist() {
    worklist=$1
    jobname=$2

    mkdir -p "${out}/cluster_logs"
    njobs=$(wc -l < "$worklist")

    sbatch \
        --wait \
        --job-name="$jobname" \
        -p "$SLURM_PARTITION" \
        --time="$SLURM_TIME" \
        --mem="$SLURM_MEM" \
        --array=1-"$njobs" \
        --output="${out}/cluster_logs/${jobname}_%A_%a.out" \
        --error="${out}/cluster_logs/${jobname}_%A_%a.err" \
        --export=ALL,WORKLIST="$worklist" <<'EOF'
#!/bin/bash
cmd=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$WORKLIST")
eval "$cmd"
EOF
}

mkdir -p "${start}/surf_temps"
out="${start}/surf_temps"
SUBJECTS_DIR=$(pwd)
echo "SUBJECTS DIR IS $SUBJECTS_DIR"

: > "${out}/init_worklist.txt"
#### initial registration
for subj in $(cat "$subjects"); do
    for hemi in lh rh; do 
        if [[ "$cluster" -eq 1 ]]; then
            echo "$PCP_PATH/utils/register_surfaces.sh ${subj} ${start} ${hemi} init" >> "${out}/init_worklist.txt" 
            mkdir -p "${start}/surf_temps/cluster_logs"
        else
            "$PCP_PATH/utils/register_surfaces.sh" "${subj}" "${start}" "${hemi}" init
        fi
    done
done

if [[ "$cluster" -eq 1 ]]; then
    submit_worklist "${out}/init_worklist.txt" "reg_init"
fi

###code block determines if the inital registrations worked or were mirrored
### uses the subcortex label generated during precon_all
### checks if the subcortex (medial wall) labels overlap after registration
### allows for orientation mismatches to be accounted for 
: > "${out}/subjects_orientation.txt"
for subj in $(cat "$subjects"); do
    dice_lh=$($PCP_PATH/utils/calc_label_dice.sh "${subj}" lh subcortex subcortex.init)
    dice_rh=$($PCP_PATH/utils/calc_label_dice.sh "${subj}" rh subcortex subcortex.init)

    if awk "BEGIN {exit !(($dice_lh < 0.2) || ($dice_rh < 0.2))}"; then
        echo "-r $subj" >> "${out}/subjects_orientation.txt"
        echo "${subj} is mirrored"
    else
        echo "$subj" >> "${out}/subjects_orientation.txt"
    fi
done


#### set up work lists
: > "${out}/oriented_worklist.txt"
### registration after mirror check
while IFS= read -r reg_args; do
# echo "$reg_args"
    for hemi in lh rh; do 
        cmd="$PCP_PATH/utils/register_surfaces.sh ${reg_args} ${start} ${hemi} oriented"
        if [[ "$cluster" -eq 1 ]]; then
            echo "$cmd" >> "${out}/oriented_worklist.txt"
        else
            echo "$cmd"
            eval "$cmd"
        fi
    done
done < "${out}/subjects_orientation.txt"

if [[ "$cluster" -eq 1 ]]; then
    submit_worklist "${out}/oriented_worklist.txt" "oriented"
fi

cp "${start}/surf/lh.sphere" "${start}/surf/lh.sphere.reg.oriented"
cp "${start}/surf/rh.sphere" "${start}/surf/rh.sphere.reg.oriented"

: > ${out}/subjs4tiftemplate.txt
echo ${start} >> ${out}/subjects_orientation.txt ### add this to the subject orientation file so it can be included in subsequent templates
echo ${start} > ${out}/subjs4tiftemplate.txt
for subj in $(cat "$subjects"); do
    echo ${subj} >> ${out}/subjs4tiftemplate.txt
done

mris_make_template lh sphere.reg.oriented `cat ${out}/subjs4tiftemplate.txt`  ${out}/lh.temp01.tif
mris_make_template rh sphere.reg.oriented `cat ${out}/subjs4tiftemplate.txt`  ${out}/rh.temp01.tif

#### set up work lists
: > "${out}/worklist_temp1.txt"
### registration after mirror check
while IFS= read -r reg_args; do
    for hemi in lh rh; do 
        cmd="$PCP_PATH/utils/register_surfaces.sh ${reg_args} ${out}/${hemi}.temp01.tif ${hemi} tif_01"
        if [[ "$cluster" -eq 1 ]]; then
            echo "$cmd" >> "${out}/worklist_temp1.txt"
        else
            echo "$cmd"
            eval "$cmd"
        fi
    done
done < "${out}/subjects_orientation.txt"

if [[ "$cluster" -eq 1 ]]; then
    submit_worklist "${out}/worklist_temp1.txt" "tif_1"
fi


mris_make_template lh sphere.reg.tif_01 `cat ${out}/subjs4tiftemplate.txt`  ${out}/lh.temp02.tif
mris_make_template rh sphere.reg.tif_01 `cat ${out}/subjs4tiftemplate.txt`  ${out}/rh.temp02.tif

#### set up work lists
: > "${out}/worklist_temp2.txt"
### registration after mirror check
while IFS= read -r reg_args; do
    for hemi in lh rh; do 
        cmd="$PCP_PATH/utils/register_surfaces.sh ${reg_args} ${out}/${hemi}.temp02.tif ${hemi} tif_02"
        if [[ "$cluster" -eq 1 ]]; then
            echo "$cmd" >> "${out}/worklist_temp2.txt"
        else
            echo "$cmd"
            eval "$cmd"
        fi
    done
done < "${out}/subjects_orientation.txt"

if [[ "$cluster" -eq 1 ]]; then
    submit_worklist "${out}/worklist_temp2.txt" "tif_2"
fi

mris_make_template lh sphere.reg.tif_02 `cat ${out}/subjs4tiftemplate.txt`  ${out}/lh.temp03.tif
mris_make_template rh sphere.reg.tif_02 `cat ${out}/subjs4tiftemplate.txt`  ${out}/rh.temp03.tif

#### set up work lists
: > "${out}/worklist_temp3.txt"
### registration after mirror check
while IFS= read -r reg_args; do
    for hemi in lh rh; do 
        cmd="$PCP_PATH/utils/register_surfaces.sh ${reg_args} ${out}/${hemi}.temp03.tif ${hemi} tif_03"
        if [[ "$cluster" -eq 1 ]]; then
            echo "$cmd" >> "${out}/worklist_temp3.txt"
        else
            echo "$cmd"
            eval "$cmd"
        fi
    done
done < "${out}/subjects_orientation.txt"

if [[ "$cluster" -eq 1 ]]; then
    submit_worklist "${out}/worklist_temp3.txt" "tif_3"
fi


mris_make_template lh sphere.reg.tif_03 `cat ${out}/subjs4tiftemplate.txt`  ${out}/lh.temp04.tif
mris_make_template rh sphere.reg.tif_03 `cat ${out}/subjs4tiftemplate.txt`  ${out}/rh.temp04.tif

: > "${out}/worklist_temp4.txt"
while IFS= read -r reg_args; do
    for hemi in lh rh; do 
        cmd="$PCP_PATH/utils/register_surfaces.sh ${reg_args} ${out}/${hemi}.temp04.tif ${hemi} tif_04"
        if [[ "$cluster" -eq 1 ]]; then
            echo "$cmd" >> "${out}/worklist_temp4.txt"
        else
            echo "$cmd"
            eval "$cmd"
        fi
    done
done < "${out}/subjects_orientation.txt"

if [[ "$cluster" -eq 1 ]]; then
    submit_worklist "${out}/worklist_temp4.txt" "tif_4"
fi

for subj in $(cat "${out}/subjs4tiftemplate.txt"); do 
    cp "${subj}/surf/lh.sphere.reg.tif_04" "${subj}/surf/lh.sphere.reg"
    cp "${subj}/surf/rh.sphere.reg.tif_04" "${subj}/surf/rh.sphere.reg"
done

echo "Done making registration template. Final registrations stores in ?h.sphere.reg to build average surfaces. "