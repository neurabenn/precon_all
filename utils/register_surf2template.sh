#!/bin/bash
# register_surf2template.sh
# Registers an individual surface to a precon_all-derived average surface,
# then resamples curv, sulc, and thickness to the average surface space.

set -euo pipefail
err() { echo "ERROR: $*" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: $(basename "$0") <precon_dir> <average_surface_dir>

  precon_dir            path to existing precon_all output directory run on a
                        single individual
  average_surface_dir   path to average surface created with precon_all's
                        pet_sounds.sh module. Target for registration.

This script runs spherical registration of a single individual to a
surface-based template built with precon_all's pet_sounds.sh module.

Outputs (in <precon_dir>/surf/):
  <hemi>.sphere.reg              - spherical registration to the template
  <hemi>.curv.std                - curv resampled to the template surface
  <hemi>.sulc.std                - sulc resampled to the template surface
  <hemi>.thickness.std           - thickness resampled to the template surface

Where <hemi> is lh, rh, or both — whichever spheres are present in precon_dir.

Requires: FreeSurfer (mris_register, mri_surf2surf) and \$SUBJECTS_DIR set
such that both the subject and the template are visible as FreeSurfer
subjects (i.e., <subj>/surf/<hemi>.sphere.reg is resolvable for both).
EOF
    exit 1
}

if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; fi
if [[ $# -ne 2 ]]; then echo "ERROR: expected 2 arguments, got $#" >&2; usage; fi

precon_dir=$1
temp_dir=$2

export SUBJECTS_DIR
SUBJECTS_DIR=$(cd "$(dirname "$precon_dir")" && pwd)
subject_id=$(basename "$precon_dir")
template_id=$(basename "$temp_dir")

[[ -e "$SUBJECTS_DIR/$template_id" ]] || ln -s "$(cd "$temp_dir" && pwd)" "$SUBJECTS_DIR/$template_id"


[[ -d "$precon_dir" ]] || err "precon_dir not found: $precon_dir"
[[ -d "$temp_dir" ]]   || err "average_surface_dir not found: $temp_dir"



# Derive FS subject IDs from directory basenames.
subject_id=$(basename "$precon_dir")
template_id=$(basename "$temp_dir")

[[ -d "$SUBJECTS_DIR/$subject_id/surf" ]] \
    || err "subject not visible in \$SUBJECTS_DIR: $SUBJECTS_DIR/$subject_id"
[[ -d "$SUBJECTS_DIR/$template_id/surf" ]] \
    || err "template not visible in \$SUBJECTS_DIR: $SUBJECTS_DIR/$template_id"

# At least one sphere must exist.
lh_sphere=${precon_dir}/surf/lh.sphere
rh_sphere=${precon_dir}/surf/rh.sphere
if [[ ! -f "$lh_sphere" && ! -f "$rh_sphere" ]]; then
    err "no sphere files in ${precon_dir}/surf/ (expected lh.sphere and/or rh.sphere)"
fi

# --- register + resample, per hemisphere present ---------------------------

for hemi in lh rh; do
    sphere="${precon_dir}/surf/${hemi}.sphere"

    if [[ ! -f "$sphere" ]]; then
        echo "Skipping $hemi hemisphere: $sphere not found"
        continue
    fi

    echo "########## Registering ${hemi} hemisphere ########"
    mris_register "$sphere" \
        "${temp_dir}/${hemi}.reg.template.tif" \
        "${precon_dir}/surf/${hemi}.sphere.reg"

    for metric in curv sulc thickness; do
        src="${precon_dir}/surf/${hemi}.${metric}"
        tgt="${precon_dir}/surf/${hemi}.${metric}.std"

        if [[ ! -f "$src" ]]; then
            echo "Skipping ${hemi}.${metric}: source not found"
            continue
        fi

        echo "########## Resampling ${hemi}.${metric} -> ${hemi}.${metric}.std ########"
        mri_surf2surf \
            --srcsubject "$subject_id" \
            --trgsubject "$template_id" \
            --hemi "$hemi" \
            --sval "$src" \
            --tval "$tgt" \
            --sfmt curv \
            --tfmt curv
    done
done

echo
echo "Done. Outputs in ${precon_dir}/surf/:"
echo "  <hemi>.sphere.reg, <hemi>.{curv,sulc,thickness}.std"