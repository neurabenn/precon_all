#!/usr/bin/env bash
set -euo pipefail

# Generate QC report for a precon_all output directory.
# All screenshots come from fsleyes (works headless via PYOPENGL_PLATFORM=osmesa).
# ImageMagick is used only for the 3D tile and PDF assembly.
#
# Behaviour:
#   - If surfaces are available -> full PDF report (3 pages)
#   - If only brain extraction is available -> just the brain extraction PNG,
#     no PDF (since a one-page PDF would just be an extra step)
#
# Usage: ./precon_report.sh /path/to/precon_all_subject_dir [suffix]
# Output: precon_report[_suffix].pdf in the subject's qc directory (if full run),
#         or qc_brain_extraction[_suffix].png alone (if only brain extraction)

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: $0 /path/to/precon_all_subject_dir [suffix]"
    exit 1
fi

# Resolve to absolute path
SUBJ_DIR="$1"
if [[ ! "$SUBJ_DIR" = /* ]]; then
    SUBJ_DIR="$(cd "$(dirname "$SUBJ_DIR")" && pwd)/$(basename "$SUBJ_DIR")"
fi
SUBJ_ID="$(basename "$SUBJ_DIR")"

# Optional suffix -- "_foo" if given, "" otherwise
SUFFIX=""
if [[ $# -ge 2 && -n "$2" ]]; then
    SUFFIX="_$2"
fi

# ---- Sanity checks ----
for cmd in fsleyes fslstats; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' not found in PATH."
        exit 1
    fi
done

if command -v magick &>/dev/null; then
    IM_CONVERT="magick"
    IM_MONTAGE="magick montage"
    echo "Using ImageMagick v7 (magick)"
elif command -v convert &>/dev/null && command -v montage &>/dev/null; then
    IM_CONVERT="convert"
    IM_MONTAGE="montage"
    echo "Using ImageMagick v6 (convert/montage)"
else
    echo "Error: ImageMagick not found."
    exit 1
fi

if [[ -z "${DISPLAY:-}" ]]; then
    export PYOPENGL_PLATFORM=osmesa
    echo "No DISPLAY set, using PYOPENGL_PLATFORM=osmesa for headless rendering"
fi

# Only mri/ is strictly required (brain extraction lives there).
# surf/ may or may not exist depending on how far the pipeline got.
if [[ ! -d "$SUBJ_DIR/mri" ]]; then
    echo "Error: '$SUBJ_DIR' missing mri/ -- not a precon_all output dir?"
    exit 1
fi

# ---- Locate key files ----
REF_VOL="$SUBJ_DIR/mri/rawavg.nii.gz"
[[ -f "$REF_VOL" ]] || REF_VOL="$SUBJ_DIR/${SUBJ_ID}_brain.nii.gz"

T1_BRAIN="$SUBJ_DIR/${SUBJ_ID}_brain.nii.gz"
BRAIN_MASK="$SUBJ_DIR/${SUBJ_ID}_brain_mask.nii.gz"
T1_HEAD="$SUBJ_DIR/sanlm_${SUBJ_ID}.nii.gz"
[[ -f "$T1_HEAD" ]] || T1_HEAD="$SUBJ_DIR/sanlm_${SUBJ_ID}_brain.nii.gz"
[[ -f "$T1_HEAD" ]] || T1_HEAD="$T1_BRAIN"

# Brain extraction outputs are strictly required (they're the minimum
# this script does anything useful with).
for f in "$T1_BRAIN" "$BRAIN_MASK" "$T1_HEAD"; do
    [[ -f "$f" ]] || { echo "Missing required file: $f"; exit 1; }
done

# REF_VOL is only needed for the coronal surface page.
HAVE_REF_VOL=1
[[ -f "$REF_VOL" ]] || HAVE_REF_VOL=0

LH_WHITE="$SUBJ_DIR/surf/lh.white.surf.gii"
LH_PIAL="$SUBJ_DIR/surf/lh.pial.surf.gii"
RH_WHITE="$SUBJ_DIR/surf/rh.white.surf.gii"
RH_PIAL="$SUBJ_DIR/surf/rh.pial.surf.gii"
WM_MASK="$SUBJ_DIR/mri/wm_orig.nii.gz"

HAVE_SURFACES=1
if [[ ! -d "$SUBJ_DIR/surf" ]]; then
    HAVE_SURFACES=0
else
    for f in "$LH_WHITE" "$LH_PIAL" "$RH_WHITE" "$RH_PIAL"; do
        [[ -f "$f" ]] || HAVE_SURFACES=0
    done
fi

# ---- Report what we detected ----
echo ""
echo "Pipeline stage detection:"
echo "  Brain extraction: yes"
if [[ $HAVE_SURFACES -eq 1 ]]; then
    echo "  Surfaces:         yes -> full PDF report"
    FULL_REPORT=1
else
    echo "  Surfaces:         no  -> brain extraction PNG only (no PDF)"
    FULL_REPORT=0
fi
echo ""

OUTPUT_DIR="$SUBJ_DIR/qc/"
mkdir -p "${OUTPUT_DIR}"
TMP_DIR="$SUBJ_DIR/.qa_tmp_$$"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

# All page PNGs target this aspect ratio / pixel canvas, so PDF pages
# all come out the same size. Letter-ish ratio (4:3).
PAGE_W=2400
PAGE_H=1800

# ---------------------------------------------------------------------------
# Page 1: Brain extraction QC -- coronal lightbox of the whole head with
# brain mask overlay in red. Same visual style as the surface QC page so
# the two are easy to compare.
# ---------------------------------------------------------------------------
create_brain_extraction_page() {
    echo "Generating brain extraction QC (lightbox + mask overlay)..."
    local out="$OUTPUT_DIR/qc_brain_extraction${SUFFIX}.png"

    fsleyes render \
        --scene lightbox \
        --bgColour 0 0 0 \
        --zaxis 1 \
        --numSlices 25 \
        --zrange 0.1 0.9 \
        --hideCursor \
        --hideLabels \
        --size $PAGE_W $PAGE_H \
        --outfile "$out" \
        "$T1_HEAD" --overlayType volume --cmap greyscale \
                   --brightness 55 --contrast 70 \
        "$BRAIN_MASK" --overlayType mask --maskColour 1 0.2 0.2 --alpha 50
}

# ---------------------------------------------------------------------------
# Page 2: Surface outline QC -- coronal lightbox of the brain with
# white (green) and pial (cyan) outlines.
# ---------------------------------------------------------------------------
create_surface_coronal_page() {
    if [[ "$HAVE_SURFACES" -ne 1 ]]; then
        echo "Surfaces not found, skipping coronal QC"
        return
    fi
    if [[ "$HAVE_REF_VOL" -ne 1 ]]; then
        echo "Reference volume not found, skipping coronal surface QC"
        return
    fi

    echo "Generating coronal surface QC..."
    local out="$OUTPUT_DIR/qc_surfaces_coronal${SUFFIX}.png"

    fsleyes render \
    --displaySpace world \
    --scene lightbox \
    --bgColour 0 0 0 \
    --zaxis 1 \
    --numSlices 16 \
    --zrange 0.15 0.85 \
    --hideCursor \
    --hideLabels \
    --size $PAGE_W $PAGE_H \
    --outfile "$out" \
    "$REF_VOL" --overlayType volume --cmap greyscale \
    "$LH_WHITE" --overlayType mesh --outline --outlineWidth 5 \
                --colour 0.2 1.0 0.2 --coordSpace affine\
    "$LH_PIAL"  --overlayType mesh --outline --outlineWidth 4 \
                --colour  0.0 1.0 1.0  --coordSpace affine\
    "$RH_WHITE" --overlayType mesh --outline --outlineWidth 5 --coordSpace affine\
                --colour  0.2 1.0 0.2  --coordSpace affine \
    "$RH_PIAL"  --overlayType mesh --outline --outlineWidth 4 \
                --colour  0.0 1.0 1.0 --coordSpace affine
}

# ---------------------------------------------------------------------------
# Page 3: 3D pial surface views -- six camera angles in a 3x2 grid.
# Render at 1000x1000 each, tiled into one big image, then padded to
# match PAGE_W x PAGE_H so the PDF page comes out the same size.
# ---------------------------------------------------------------------------
create_3d_surface_page() {
    [[ "$HAVE_SURFACES" -eq 1 ]] || return

    echo "Generating 3D surface views..."

    local i=0
    for view in left posterior right anterior dorsal ventral; do
        i=$((i+1))

        local rot
        local light_args=()
        case $view in
            left)      rot="-90 0 0" ;;
            posterior) rot="0 0 0" ;;
            right)     rot="90 0 0" ;;
            anterior)  rot="180 0 0" ;;
            dorsal)    rot="0 -90 0" ;;
            ventral)   rot="0 90 0"
                       light_args=(--lightPos 180.0 -180.0 0.0) ;;
        esac

        fsleyes render \
            --scene 3d \
            --hideCursor \
            --bgColour 0 0 0 \
            --size 1000 1000 \
            --cameraRotation $rot \
            "${light_args[@]}" \
            --outfile "$TMP_DIR/3d-$(printf '%02d' $i)-$view.png" \
            "$LH_PIAL" --overlayType mesh \
                       --outline --outlineWidth 2 \
                       --colour 0.0 1.0 1.0 \
            "$RH_PIAL" --overlayType mesh \
                       --outline --outlineWidth 2 \
                       --colour 0.0 1.0 1.0
    done

    # Tile the six panels into one image
    local tiled="$TMP_DIR/3d-tiled.png"
    $IM_MONTAGE "$TMP_DIR"/3d-0*.png \
        -tile 3x2 \
        -geometry +4+4 \
        -background black \
        "$tiled"

    # Trim and add a thin black border. The final resize to match the
    # lightbox pages happens after all pages are rendered.
    $IM_CONVERT "$tiled" \
        -trim +repage \
        -bordercolor black -border 40 \
        "$OUTPUT_DIR/qc_surfaces_3d${SUFFIX}.png"

    rm -f "$TMP_DIR"/3d-*.png
}

# ---------------------------------------------------------------------------
# Run all
# ---------------------------------------------------------------------------
echo "Subject:   $SUBJ_ID"
echo "Directory: $SUBJ_DIR"
echo "Reference: $REF_VOL"
[[ -n "$SUFFIX" ]] && echo "Suffix:    ${SUFFIX#_}"

create_brain_extraction_page
create_surface_coronal_page
create_3d_surface_page


# ---------------------------------------------------------------------------
# If only brain extraction ran, stop here -- the PNG is the deliverable.
# ---------------------------------------------------------------------------
if [[ $FULL_REPORT -eq 0 ]]; then
    BRAIN_EXT_PNG="$OUTPUT_DIR/qc_brain_extraction${SUFFIX}.png"
    if [[ -f "$BRAIN_EXT_PNG" ]]; then
        echo ""
        echo "Brain extraction only -- no PDF generated."
        echo "Wrote: $BRAIN_EXT_PNG"
        exit 0
    else
        echo "Error: brain extraction PNG was not generated."
        exit 1
    fi
fi

# ---- Match the 3D page dimensions to the lightbox pages ----
# The lightbox pages are produced directly by fsleyes at PAGE_W x PAGE_H.
# Resize the 3D output to match so all three pages are the same size.
if [[ -f "$OUTPUT_DIR/qc_brain_extraction${SUFFIX}.png" && -f "$OUTPUT_DIR/qc_surfaces_3d${SUFFIX}.png" ]]; then
    # Read the target dimensions from one of the lightbox PNGs
    read TARGET_W TARGET_H <<< $($IM_CONVERT "$OUTPUT_DIR/qc_brain_extraction${SUFFIX}.png" \
        -format "%w %h" info:)
    echo "Resizing 3D page to ${TARGET_W}x${TARGET_H} (to match lightbox pages)"

    $IM_CONVERT "$OUTPUT_DIR/qc_surfaces_3d${SUFFIX}.png" \
        -resize ${TARGET_W}x${TARGET_H} \
        -background black -gravity center -extent ${TARGET_W}x${TARGET_H} \
        "$OUTPUT_DIR/qc_surfaces_3d${SUFFIX}.png"
fi

# ---------------------------------------------------------------------------
# Compile PDF -- all pages on the same canvas size
# ---------------------------------------------------------------------------
PDF_OUT="$OUTPUT_DIR/precon_report${SUFFIX}.pdf"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
if [[ -n "$SUFFIX" ]]; then
    LABEL="$SUBJ_ID  |  ${SUFFIX#_}  |  $TIMESTAMP"
else
    LABEL="$SUBJ_ID  |  $TIMESTAMP"
fi

pages=(
    "$OUTPUT_DIR/qc_brain_extraction${SUFFIX}.png"
    "$OUTPUT_DIR/qc_surfaces_coronal${SUFFIX}.png"
    "$OUTPUT_DIR/qc_surfaces_3d${SUFFIX}.png"
)

# Resize each page to the standard canvas before PDF assembly so all
# pages render at the same physical size in the PDF.
existing=()
for img in "${pages[@]}"; do
    if [[ -f "$img" ]]; then
        local_normalised="${img%.png}_norm.png"
        $IM_CONVERT "$img" \
            -resize ${PAGE_W}x${PAGE_H} \
            -background black \
            -gravity center \
            -extent ${PAGE_W}x${PAGE_H} \
            "$local_normalised"
        existing+=("$local_normalised")
    fi
done

if (( ${#existing[@]} > 0 )); then
    args=()
    for img in "${existing[@]}"; do
        args+=( "(" "$img" -gravity southeast -fill white \
                -undercolor '#00000080' -pointsize 24 \
                -annotate +20+20 "$LABEL" ")" )
    done
    $IM_CONVERT -density 150 "${args[@]}" "$PDF_OUT"
    # Clean up normalised copies
    for img in "${existing[@]}"; do rm -f "$img"; done
    echo ""
    echo "Wrote: $PDF_OUT"
else
    echo "No QC images generated."
    exit 1
fi