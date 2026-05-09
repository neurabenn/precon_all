#!/bin/bash
# precon_all logging utilities — sourced from surfing_safari.sh
# Provides: full log + timestamped event log, run_step wrapper, summary.
# Does NOT modify behaviour of underlying scripts.

# ---------------------------------------------------------------------------
# Setup. Call once at the start of surfing_safari.sh after brain_dir is known.
# Usage: precon_logging_init <brain_dir> <subject_path> <steps> <animal>
# ---------------------------------------------------------------------------
precon_logging_init() {
    local brain_dir="$1"
    local subject="$2"
    local steps="$3"
    local animal="$4"

    mkdir -p "${brain_dir}/logs"
    PRECON_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    PRECON_FULL_LOG="${brain_dir}/logs/run_${PRECON_TIMESTAMP}.log"
    PRECON_EVENT_LOG="${brain_dir}/logs/run_${PRECON_TIMESTAMP}_events.log"

    # Tee all stdout/stderr into the full log (terminal still gets it)
    exec > >(tee -a "$PRECON_FULL_LOG")
    exec 2> >(tee -a "$PRECON_FULL_LOG" >&2)

    # Track step timings for end-of-run summary
    PRECON_STEP_NAMES=()
    PRECON_STEP_TIMES=()
    PRECON_SUBJECT="$subject"
    PRECON_STEPS="$steps"
    PRECON_ANIMAL="$animal"

    event "=== precon_all run started ==="
    event "subject:    ${subject}"
    event "steps:      ${steps}"
    event "animal:     ${animal}"
    event "host:       $(hostname)"
    event "user:       $(whoami)"
    event "full log:   ${PRECON_FULL_LOG}"
    event "event log:  ${PRECON_EVENT_LOG}"
    event ""
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------
event() {
    local msg
    msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    if [ -n "${PRECON_EVENT_LOG:-}" ]; then
        echo "$msg" >> "$PRECON_EVENT_LOG"
    fi
}

precon_fmt_duration() {
    local s=$1
    local h=$((s / 3600))
    local m=$(((s % 3600) / 60))
    local sec=$((s % 60))
    if [ $h -gt 0 ]; then printf '%dh %dm %ds' $h $m $sec
    elif [ $m -gt 0 ]; then printf '%dm %ds' $m $sec
    else printf '%ds' $sec
    fi
}

# ---------------------------------------------------------------------------
# Wrap a step with timing and event logging.
# Behaviour preserved: if step fails, exits with same code (matches what
# would happen if surfing_safari.sh hit a hard failure anyway).
# Usage: run_step <name> <command> [args...]
# ---------------------------------------------------------------------------
run_step() {
    local name="$1"
    shift
    event ">>> START: ${name}"
    local t0=$SECONDS
    "$@"
    local rc=$?
    local elapsed=$((SECONDS - t0))
    local pretty
    pretty=$(precon_fmt_duration "$elapsed")
    if [ $rc -eq 0 ]; then
        event "<<< OK:    ${name} (${pretty})"
        PRECON_STEP_NAMES+=("$name")
        PRECON_STEP_TIMES+=("$pretty")
    else
        event "<<< FAIL:  ${name} (${pretty}, exit ${rc})"
        event ""
        event "Pipeline failed at step: ${name}"
        event "Resume options:"
        event "  precon_1 = brain extraction only"
        event "  precon_2 = denoise + segmentation + WM fill"
        event "  precon_3 = WM fill + surfaces"
        event ""
        event "Rerun: surfing_safari.sh -i ${PRECON_SUBJECT} -r <stage> -a ${PRECON_ANIMAL}"
        event ""
        event "Logs:"
        event "  full:  ${PRECON_FULL_LOG}"
        event "  event: ${PRECON_EVENT_LOG}"
        exit $rc
    fi
}

# ---------------------------------------------------------------------------
# Print summary table at end of run. Call from end of surfing_safari.sh.
# ---------------------------------------------------------------------------
precon_logging_summary() {
    event ""
    event "=== SUMMARY ==="
    local i
    for i in "${!PRECON_STEP_NAMES[@]}"; do
        local line
        line=$(printf '  %-25s %s' "${PRECON_STEP_NAMES[$i]}" "${PRECON_STEP_TIMES[$i]}")
        event "${line}"
    done
    event "=== precon_all run completed successfully ==="
}