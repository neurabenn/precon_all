#!/bin/bash
# ants_to_fsl_warp.sh
# Convert an ANTs warp + affine pair into FSL applywarp format and apply.
#
# Pipeline:
#   1. Split the 5D ITK warp into x/y/z components (ImageMath).
#   2. Sign-flip components based on reference orientation:
#        NEUROLOGICAL  -> Y flip only
#        RADIOLOGICAL  -> X and Y flip
#      Then merge to a 4D FSL warp.
#   3. Convert ANTs affine -> FSL .mat via ITK->RAS (folds in FixedParameters)
#      -> LPS ITK text with FixedParameters=0 -> lta_convert --outfsl.
#   4. Concatenate the FSL affine and warp into a single combined warp
#      (str2std_warp.nii.gz) with convertwarp.
#   5. Invert the combined warp (std2str_warp.nii.gz) with invwarp.
#   6. Apply forward and inverse warps as sanity checks (FSLWarped /
#      FSLInverseWarped).
#   7. Clean up intermediates, keeping only the final outputs.
#
# All outputs are written to the directory containing <ants_warp>.

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") <ref> <moving> <ants_warp> <ants_affine>

Convert an ANTs warp + affine into FSL format, build forward and inverse
combined warps, and apply both as sanity checks.

Arguments:
  ref           Reference (template) image. Must be NEUROLOGICAL or
                RADIOLOGICAL orientation; reorient with fslreorient2std first
                if neither.
  moving        Moving (subject) image, the source space for str2std_warp.
  ants_warp     ANTs nonlinear warp (e.g. ANTSREG1Warp.nii.gz, 5D ITK vector).
                ALL OUTPUTS are written to this file's directory.
  ants_affine   ANTs affine transform (e.g. ANTSREG0GenericAffine.mat, ITK binary).

Final outputs (written to the directory containing ants_warp):
  ants_warp_fsl.nii.gz       - FSL-format relative warp (subject->template)
  ants_affine_fsl.mat        - FSL-format affine (subject->template)
  str2std_warp.nii.gz        - combined affine+warp, subject->template
  std2str_warp.nii.gz        - inverse combined warp, template->subject
  FSLWarped.nii.gz           - sanity check: moving warped into reference space
  FSLInverseWarped.nii.gz    - sanity check: reference warped into moving space

Intermediate files are cleaned up automatically.

Requires: ANTs (ImageMath, ConvertTransformFile), FSL (fslmaths, fslmerge,
applywarp, fslorient, convertwarp, invwarp), FreeSurfer (lta_convert), awk.

Example:
  $(basename "$0") template.nii.gz subject.nii.gz \\
    /path/to/reg/ANTSREG1Warp.nii.gz \\
    /path/to/reg/ANTSREG0GenericAffine.mat
  # All outputs land in /path/to/reg/
EOF
}

# --- argument parsing ------------------------------------------------------

if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 4 ]]; then
  echo "ERROR: expected 4 arguments, got $#" >&2
  echo >&2
  usage >&2
  exit 1
fi

REF=$1
MOVING=$2
ANTS_WARP=$3
ANTS_AFFINE=$4

# --- input validation ------------------------------------------------------

err() { echo "ERROR: $*" >&2; exit 1; }

for f in "$REF" "$MOVING" "$ANTS_WARP" "$ANTS_AFFINE"; do
  [[ -f "$f" ]] || err "input file not found: $f"
  [[ -r "$f" ]] || err "input file not readable: $f"
done

for tool in ImageMath ConvertTransformFile fslmaths fslmerge applywarp \
            fslorient convertwarp invwarp lta_convert awk; do
  command -v "$tool" >/dev/null 2>&1 || err "required tool not found on PATH: $tool"
done

OUT_DIR=$(cd "$(dirname "$ANTS_WARP")" && pwd)
[[ -d "$OUT_DIR" ]] || err "output directory does not exist: $OUT_DIR"
[[ -w "$OUT_DIR" ]] || err "output directory is not writable: $OUT_DIR"

ORIENT=$(fslorient -getorient "$REF" 2>/dev/null || echo "UNKNOWN")
if [[ "$ORIENT" != "NEUROLOGICAL" && "$ORIENT" != "RADIOLOGICAL" ]]; then
  err "reference orientation is '$ORIENT', expected NEUROLOGICAL or RADIOLOGICAL.
       Reorient first with: fslreorient2std $REF <new_ref>"
fi

# --- intermediates: collect for cleanup ------------------------------------

INTERMEDIATES=(
  "$OUT_DIR/warp_x.nii.gz"
  "$OUT_DIR/warp_y.nii.gz"
  "$OUT_DIR/warp_z.nii.gz"
  "$OUT_DIR/warp_x_use.nii.gz"
  "$OUT_DIR/warp_y_use.nii.gz"
  "$OUT_DIR/warp_z_use.nii.gz"
  "$OUT_DIR/ants_affine_ras.mat"
  "$OUT_DIR/ants_affine_zerocenter.txt"
)

cleanup() {
  echo "Cleaning up intermediates..."
  for f in "${INTERMEDIATES[@]}"; do
    [[ -f "$f" ]] && rm -f "$f"
  done
}
trap cleanup EXIT

# --- header ---------------------------------------------------------------

echo "Converting ANTs -> FSL"
echo "  ref         : $REF ($ORIENT)"
echo "  moving      : $MOVING"
echo "  ants warp   : $ANTS_WARP"
echo "  ants affine : $ANTS_AFFINE"
echo "  output dir  : $OUT_DIR"

# --- [1/5] warp: split, orientation-aware sign flips, merge ---------------

echo "[1/5] Splitting and converting warp..."
ImageMath 3 "$OUT_DIR/warp_x.nii.gz" ExtractVectorComponent "$ANTS_WARP" 0
ImageMath 3 "$OUT_DIR/warp_y.nii.gz" ExtractVectorComponent "$ANTS_WARP" 1
ImageMath 3 "$OUT_DIR/warp_z.nii.gz" ExtractVectorComponent "$ANTS_WARP" 2

case "$ORIENT" in
  NEUROLOGICAL)
    cp "$OUT_DIR/warp_x.nii.gz" "$OUT_DIR/warp_x_use.nii.gz"
    fslmaths "$OUT_DIR/warp_y.nii.gz" -mul -1 "$OUT_DIR/warp_y_use.nii.gz"
    cp "$OUT_DIR/warp_z.nii.gz" "$OUT_DIR/warp_z_use.nii.gz"
    ;;
  RADIOLOGICAL)
    fslmaths "$OUT_DIR/warp_x.nii.gz" -mul -1 "$OUT_DIR/warp_x_use.nii.gz"
    fslmaths "$OUT_DIR/warp_y.nii.gz" -mul -1 "$OUT_DIR/warp_y_use.nii.gz"
    cp "$OUT_DIR/warp_z.nii.gz" "$OUT_DIR/warp_z_use.nii.gz"
    ;;
esac

fslmerge -t "$OUT_DIR/ants_warp_fsl.nii.gz" \
  "$OUT_DIR/warp_x_use.nii.gz" \
  "$OUT_DIR/warp_y_use.nii.gz" \
  "$OUT_DIR/warp_z_use.nii.gz"

# --- [2/5] affine: ITK binary -> RAS 4x4 -> LPS ITK text -> FSL ----------

echo "[2/5] Converting affine..."
ConvertTransformFile 3 "$ANTS_AFFINE" "$OUT_DIR/ants_affine_ras.mat" --hm --ras

awk '
  NR<=3 { for (i=1; i<=4; i++) m[NR,i] = $i }
  END {
    if (NR < 3) { print "ERROR: RAS matrix has fewer than 3 rows" > "/dev/stderr"; exit 1 }
    m[1,3] = -m[1,3]; m[2,3] = -m[2,3]
    m[3,1] = -m[3,1]; m[3,2] = -m[3,2]
    m[1,4] = -m[1,4]; m[2,4] = -m[2,4]
    print "#Insight Transform File V1.0"
    print "#Transform 0"
    print "Transform: AffineTransform_double_3_3"
    printf "Parameters:"
    for (r=1; r<=3; r++) for (c=1; c<=3; c++) printf " %.16g", m[r,c]
    for (r=1; r<=3; r++) printf " %.16g", m[r,4]
    printf "\n"
    print "FixedParameters: 0 0 0"
  }
' "$OUT_DIR/ants_affine_ras.mat" > "$OUT_DIR/ants_affine_zerocenter.txt"

[[ -s "$OUT_DIR/ants_affine_zerocenter.txt" ]] \
  || err "failed to write LPS ITK text file (awk produced empty output)"

lta_convert \
  --initk "$OUT_DIR/ants_affine_zerocenter.txt" \
  --outfsl "$OUT_DIR/ants_affine_fsl.mat" \
  --src "$MOVING" \
  --trg "$REF"

[[ -s "$OUT_DIR/ants_affine_fsl.mat" ]] || err "lta_convert produced empty output"

# --- [3/5] combine affine + warp into a single forward warp ---------------

echo "[3/5] Building combined forward warp str2std_warp.nii.gz..."
convertwarp \
  --ref="$REF" \
  --premat="$OUT_DIR/ants_affine_fsl.mat" \
  --warp1="$OUT_DIR/ants_warp_fsl.nii.gz" \
  --rel \
  --out="$OUT_DIR/str2std_warp.nii.gz"

[[ -s "$OUT_DIR/str2std_warp.nii.gz" ]] || err "convertwarp produced empty output"

# --- [4/5] invert combined warp -> std2str_warp.nii.gz --------------------

echo "[4/5] Inverting combined warp -> std2str_warp.nii.gz..."
invwarp \
  --ref="$MOVING" \
  --warp="$OUT_DIR/str2std_warp.nii.gz" \
  --out="$OUT_DIR/std2str_warp.nii.gz"

[[ -s "$OUT_DIR/std2str_warp.nii.gz" ]] || err "invwarp produced empty output"

# --- [5/5] sanity-check applies (forward and inverse) ---------------------

echo "[5/5] Applying forward and inverse warps as sanity checks..."

applywarp \
  -i "$MOVING" \
  -r "$REF" \
  -w "$OUT_DIR/str2std_warp.nii.gz" \
  -o "$OUT_DIR/FSLWarped.nii.gz"

[[ -s "$OUT_DIR/FSLWarped.nii.gz" ]] || err "applywarp (forward) produced empty output"

applywarp \
  -i "$REF" \
  -r "$MOVING" \
  -w "$OUT_DIR/std2str_warp.nii.gz" \
  -o "$OUT_DIR/FSLInverseWarped.nii.gz"

[[ -s "$OUT_DIR/FSLInverseWarped.nii.gz" ]] || err "applywarp (inverse) produced empty output"

echo
echo "Done. Outputs in $OUT_DIR:"
echo "  ants_warp_fsl.nii.gz       - FSL warp only ($ORIENT-aware)"
echo "  ants_affine_fsl.mat        - FSL affine only"
echo "  str2std_warp.nii.gz        - combined subject->template warp"
echo "  std2str_warp.nii.gz        - inverse template->subject warp"
echo "  FSLWarped.nii.gz           - sanity check: subject in template space"
echo "  FSLInverseWarped.nii.gz    - sanity check: template in subject space"
# echo
# echo "To validate against ANTs ground truth:"
# echo "  antsApplyTransforms -d 3 -i $MOVING -r $REF \\"
# echo "    -t $ANTS_WARP -t $ANTS_AFFINE -o $OUT_DIR/ants_truth.nii.gz"
# echo "  fslmaths $OUT_DIR/ants_truth.nii.gz -sub $OUT_DIR/FSLWarped.nii.gz \\"
# echo "    $OUT_DIR/diff.nii.gz"
# echo "  fslstats $OUT_DIR/diff.nii.gz -R -M -S    # expect sub-voxel differences"