#!/bin/bash

err() {
    echo "ERROR: $*" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [options] <source_subject> <target_subject|target_template.tif> <hemi> [suffix]

Register a precon_all output directory to either:
1. another individual subject, or
2. a direct template tif file for mris_register

Arguments:
  source_subject   subject whose data gets warped
  target_subject   target subject providing the reference mesh or template,
                   OR a direct template tif file for mris_register
  hemi             hemisphere to process; must be lh or rh
  suffix           optional tag for outputs
                   default: to_<target_subject_basename>

Options:
  -r, --reverse              pass -reverse to mris_register
  --target-subject <subject> optional when target_subject is a .tif file;
                             if provided, enables downstream surf/label propagation
EOF
    exit 1
}

reverse=0
target_ref_arg=""
hemi=""
suffix=""
positionals=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--reverse)
            reverse=1
            shift
            ;;
        --target-subject)
            [[ $# -ge 2 ]] || err "--target-subject requires an argument"
            target_ref_arg=$2
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        --)
            shift
            while [[ $# -gt 0 ]]; do
                positionals+=("$1")
                shift
            done
            ;;
        -*)
            err "unknown option: $1"
            ;;
        *)
            positionals+=("$1")
            shift
            ;;
    esac
done

[[ ${#positionals[@]} -ge 3 ]] || usage
[[ ${#positionals[@]} -le 4 ]] || err "unexpected extra argument: ${positionals[4]}"

src_arg=${positionals[0]}
trg_arg=${positionals[1]}
hemi=${positionals[2]}
suffix=${positionals[3]:-}

[[ "$hemi" == "lh" || "$hemi" == "rh" ]] || err "hemi must be specified as 'lh' or 'rh'"
SUBJECTS_DIR=${SUBJECTS_DIR:-$(pwd -P)}
export SUBJECTS_DIR

src_id=${src_arg%/}
trg_input=${trg_arg%/}

if [[ "$trg_input" == *.tif ]]; then
    target_mode=tif
    if [[ "$trg_input" = /* ]]; then
        template=$trg_input
    else
        template="$SUBJECTS_DIR/$trg_input"
    fi
    [[ -f "$template" ]] || err "template tif not found: $template"

    if [[ -n "$target_ref_arg" ]]; then
        trg_id=${target_ref_arg%/}
        do_downstream=1
    else
        trg_id=""
        do_downstream=0
    fi

    target_tag=$(basename "${trg_input%.tif}")
else
    target_mode=subject
    trg_id=$trg_input
    template=""
    do_downstream=1
    target_tag=$(basename "$trg_id")
fi

[[ -n "$suffix" ]] || suffix="to_${target_tag}"

src_surf="$SUBJECTS_DIR/$src_id/surf"
src_label="$SUBJECTS_DIR/$src_id/label"

[[ -d "$src_surf" ]] || err "source not under \$SUBJECTS_DIR: $SUBJECTS_DIR/$src_id"
[[ -f "$src_surf/${hemi}.sphere" ]] || err "missing $src_surf/${hemi}.sphere"

if [[ $do_downstream -eq 1 ]]; then
    trg_surf="$SUBJECTS_DIR/$trg_id/surf"
    trg_label="$SUBJECTS_DIR/$trg_id/label"
    [[ -d "$trg_surf" ]] || err "target not under \$SUBJECTS_DIR: $SUBJECTS_DIR/$trg_id"
    [[ -f "$trg_surf/${hemi}.sphere" ]] || err "missing $trg_surf/${hemi}.sphere"
else
    trg_surf=""
    trg_label=""
fi

echo "SUBJECTS_DIR = $SUBJECTS_DIR"
echo "source       = $src_id"
echo "target input = $trg_input"
echo "target ref   = ${trg_id:-<none>}"
echo "target mode  = $target_mode"
echo "downstream   = $do_downstream"
echo "hemi         = $hemi"
echo "suffix       = $suffix"
echo "reverse      = $reverse"

regname="sphere.reg.$suffix"

register_opts=(-1)
[[ $reverse -eq 1 ]] && register_opts+=(-reverse)

template_opts=()
[[ $reverse -eq 1 ]] && template_opts+=(-reverse)

ssrc="$src_surf/${hemi}.sphere"

if command -v mris_euler_number >/dev/null 2>&1; then
    echo "----- $hemi euler check -----"
    mris_euler_number "$ssrc" 2>&1 | grep -i euler || true
    if [[ $do_downstream -eq 1 ]]; then
        mris_euler_number "$trg_surf/${hemi}.sphere" 2>&1 | grep -i euler || true
    fi
fi

if [[ -n "$template" ]]; then
    echo "########## Registering $hemi : $src_id -> template ($template) ##########"
    mris_register "${template_opts[@]}" \
        "$ssrc" \
        "$template" \
        "$src_surf/${hemi}.${regname}" \
        2>&1 | tee "$src_surf/${hemi}.register.${suffix}.log"

    if [[ $do_downstream -eq 1 ]]; then
        if [[ -f "$trg_surf/${hemi}.sphere.reg" ]]; then
            ln -sfn "${hemi}.sphere.reg" "$trg_surf/${hemi}.${regname}"
        elif [[ -f "$trg_surf/${hemi}.sphere" ]]; then
            echo "WARNING: $trg_surf/${hemi}.sphere.reg is missing; using ${hemi}.sphere for downstream surfreg"
            ln -sfn "${hemi}.sphere" "$trg_surf/${hemi}.${regname}"
        else
            err "template registration selected, but neither $trg_surf/${hemi}.sphere.reg nor $trg_surf/${hemi}.sphere exists"
        fi
    else
        echo "No --target-subject provided for .tif target; registration only"
    fi
else
    strg="$trg_surf/${hemi}.sphere"
    echo "########## Registering $hemi : $src_id -> $trg_id ##########"
    mris_register "${register_opts[@]}" \
        "$ssrc" \
        "$strg" \
        "$src_surf/${hemi}.${regname}" \
        2>&1 | tee "$src_surf/${hemi}.register.${suffix}.log"

    ln -sfn "${hemi}.sphere" "$trg_surf/${hemi}.${regname}"
fi

if [[ $do_downstream -eq 0 ]]; then
    echo
    echo "Done."
    echo "Registration written to ${src_surf}/${hemi}.${regname}"
    exit 0
fi

# Original behavior preserved: source metrics are resampled onto target mesh
# and written in the source folder.
for metric in curv sulc thickness; do
    msrc="$src_surf/${hemi}.${metric}"
    if [[ ! -f "$msrc" ]]; then
        echo "Skipping ${hemi}.${metric}: not found on source"
        continue
    fi
    out="$src_surf/${hemi}.${metric}.${suffix}"
    echo "########## Resampling ${hemi}.${metric} -> ${out} ##########"
    mri_surf2surf \
        --srcsubject "$src_id" \
        --trgsubject "$trg_id" \
        --hemi "$hemi" \
        --surfreg "$regname" \
        --sval "$msrc" \
        --tval "$out" \
        --sfmt curv --tfmt curv \
        2>&1 | tee "$src_surf/${hemi}.${metric}.${suffix}.log"
    [[ ${PIPESTATUS[0]} -eq 0 ]] || err "mri_surf2surf failed for ${hemi}.${metric}"
done

for lab in cortex subcortex; do
    tlabel="$trg_label/${hemi}.${lab}.label"
    if [[ ! -f "$tlabel" ]]; then
        echo "Skipping ${hemi}.${lab}: not found on target ($tlabel)"
        continue
    fi
    mkdir -p "$src_label"
    lout="$src_label/${hemi}.${lab}.${suffix}.label"
    echo "########## Mapping ${hemi}.${lab} ($trg_id -> $src_id) -> ${lout} ##########"
    mri_label2label \
        --srcsubject "$trg_id" \
        --srclabel "$tlabel" \
        --trgsubject "$src_id" \
        --trglabel "$lout" \
        --regmethod surface \
        --hemi "$hemi" \
        --srcsurfreg "$regname" \
        --trgsurfreg "$regname" \
        2>&1 | tee "$src_label/${hemi}.${lab}.${suffix}.log"
    [[ ${PIPESTATUS[0]} -eq 0 ]] || err "mri_label2label failed for ${hemi}.${lab}"
done

echo
echo "Done."
echo "Outputs written in ${src_id}:"
echo "  surf/<hemi>.sphere.reg.${suffix}"
echo "  surf/<hemi>.{curv,sulc,thickness}.${suffix}"
echo "  label/<hemi>.{cortex,subcortex}.${suffix}.label"
echo "Registration logs: ${src_surf}/<hemi>.register.${suffix}.log"