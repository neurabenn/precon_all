usage() {
    cat <<EOF
Usage: $(basename "$0") [-r|--reverse] <source_subject> <target_subject> [suffix]

Register a precon_all output directory to either:
  1. another individual subject, or
  2. a template built with precon_all (via <hemi>*.tif files, if present)

Arguments:
  source_subject   subject whose data gets warped (e.g. fake_T1)
  target_subject   subject providing the reference mesh or template
                   (e.g. struct_brain_1mm or avg_NIMH_mac_brain)
  suffix           optional tag for outputs
                   default: to_<target_subject>

Options:
  -r, --reverse    pass -reverse to mris_register

Notes:
  Both subjects must live under a common \$SUBJECTS_DIR (paths or bare IDs ok).
  A symlink to a template subject is also fine if needed.

Outputs written in <source_subject>/surf/:
  <hemi>.sphere.reg.<suffix>
  <hemi>.curv.<suffix>
  <hemi>.sulc.<suffix>
  <hemi>.thickness.<suffix>

Outputs written in <source_subject>/label/:
  <hemi>.cortex.<suffix>.label

Quality control:
  Visually inspect the resampled cortex labels in source space.
  If registration fails or the medial wall appears on the lateral surface,
  rerun with -r as a first troubleshooting step.
EOF
    exit 1
}

reverse=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--reverse) reverse=1; shift ;;
        -h|--help) usage ;;
        --) shift; break ;;
        -*) err "unknown option: $1" ;;
        *) break ;;
    esac
done

[[ $# -ge 2 ]] || usage

src_arg=$1
trg_arg=$2

# --- resolve SUBJECTS_DIR and subject IDs ---------------------------------
# Accept either a path or a bare ID; require both under one SUBJECTS_DIR.
resolve_parent() { cd "$(dirname "$1")" && pwd; }

if [[ -d "$src_arg" ]]; then
    SUBJECTS_DIR=$(resolve_parent "$src_arg")
elif [[ -n "${SUBJECTS_DIR:-}" && -d "$SUBJECTS_DIR/$src_arg" ]]; then
    :  # SUBJECTS_DIR already set and valid
else
    err "cannot locate source '$src_arg' (pass a path, or set \$SUBJECTS_DIR)"
fi
export SUBJECTS_DIR

src_id=$(basename "$src_arg")
trg_id=$(basename "$trg_arg")
suffix=${3:-to_${trg_id}}

[[ -d "$SUBJECTS_DIR/$src_id/surf" ]] || err "source not under \$SUBJECTS_DIR: $SUBJECTS_DIR/$src_id"
[[ -d "$SUBJECTS_DIR/$trg_id/surf" ]] || err "target not under \$SUBJECTS_DIR: $SUBJECTS_DIR/$trg_id"

echo "SUBJECTS_DIR = $SUBJECTS_DIR"
echo "source       = $src_id"
echo "target       = $trg_id"
echo "suffix       = $suffix"
echo "reverse      = $reverse"

src_surf="$SUBJECTS_DIR/$src_id/surf"
trg_surf="$SUBJECTS_DIR/$trg_id/surf"
src_label="$SUBJECTS_DIR/$src_id/label"
trg_label="$SUBJECTS_DIR/$trg_id/label"
regname="sphere.reg.$suffix"

register_opts=(-1)
[[ $reverse -eq 1 ]] && register_opts+=(-reverse)

# at least one sphere must exist on each side
if [[ ! -f "$src_surf/lh.sphere" && ! -f "$src_surf/rh.sphere" ]]; then
    err "no {lh,rh}.sphere in $src_surf"
fi

for hemi in lh rh; do
    ssrc="$src_surf/${hemi}.sphere"
    strg="$trg_surf/${hemi}.sphere"

    if [[ ! -f "$ssrc" || ! -f "$strg" ]]; then
        echo "Skipping $hemi: need ${hemi}.sphere on BOTH subjects"
        continue
    fi

    # sanity: warn on a topologically broken sphere before wasting a registration
    if command -v mris_euler_number >/dev/null 2>&1; then
        echo "----- $hemi euler check -----"
        mris_euler_number "$ssrc" 2>&1 | grep -i euler || true
        mris_euler_number "$strg" 2>&1 | grep -i euler || true
    fi

    # target subject may ship a canonical atlas template (<hemi>*.tif) in its
    # subject root; if so, register through that instead of a direct pairwise (-1) fit.
    template=$(compgen -G "$SUBJECTS_DIR/$trg_id/${hemi}*.tif" | head -n1 || true)

    if [[ -n "$template" ]]; then
        echo "########## Registering $hemi : $src_id -> template ($template) ##########"
        template_opts=()
        [[ $reverse -eq 1 ]] && template_opts+=(-reverse)
        mris_register ${template_opts[@]+"${template_opts[@]}"} \
            "$ssrc" \
            "$template" \
            "$src_surf/${hemi}.${regname}" \
            2>&1 | tee "$src_surf/${hemi}.register.${suffix}.log"

        # target should already be registered to this same atlas (e.g. from recon-all).
        [[ -f "$trg_surf/${hemi}.sphere.reg" ]] || err "template found ($template) but $trg_surf/${hemi}.sphere.reg is missing"
        ln -sfn "${hemi}.sphere.reg" "$trg_surf/${hemi}.${regname}"
    else
        # --- register source sphere directly to target sphere (-1, near-rigid) ---
        echo "########## Registering $hemi : $src_id -> $trg_id ##########"
        mris_register "${register_opts[@]}" \
            "$ssrc" \
            "$strg" \
            "$src_surf/${hemi}.${regname}" \
            2>&1 | tee "$src_surf/${hemi}.register.${suffix}.log"

        # target is the fixed side: its own sphere IS its registration frame.
        # give it a matching reg name so one --surfreg value works for both.
        ln -sfn "${hemi}.sphere" "$trg_surf/${hemi}.${regname}"
    fi

    # --- resample source metrics onto the target mesh, save in source folder ---
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
            --sfmt curv --tfmt curv
    done

    # --- carry target's cortex label back onto the source mesh ---------------
    tlabel="$trg_label/${hemi}.cortex.label"
    if [[ ! -f "$tlabel" ]]; then
        echo "Skipping ${hemi}.cortex: not found on target ($tlabel)"
        continue
    fi
    mkdir -p "$src_label"
    lout="$src_label/${hemi}.cortex.${suffix}.label"
    echo "########## Mapping ${hemi}.cortex ($trg_id -> $src_id) -> ${lout} ##########"
    mri_label2label \
        --srcsubject "$trg_id" \
        --srclabel "$tlabel" \
        --trgsubject "$src_id" \
        --trglabel "$lout" \
        --regmethod surface \
        --hemi "$hemi" \
        --srcsurfreg "$regname" \
        --trgsurfreg "$regname"
done

echo
echo "Done."
echo "Outputs written in ${src_id}:"
echo "  surf/<hemi>.sphere.reg.${suffix}"
echo "  surf/<hemi>.{curv,sulc,thickness}.${suffix}"
echo "  label/<hemi>.cortex.${suffix}.label"
echo "Registration logs: ${src_surf}/<hemi>.register.${suffix}.log"