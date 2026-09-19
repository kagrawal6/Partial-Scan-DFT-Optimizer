#!/usr/bin/env bash
# Convenience launcher for the Synopsys Design Vision / TetraMAX flow.
#
# Required:
#   export SAED32_ROOT=/path/to/saed32_edk
#
# Tools are resolved from PATH, or from DESIGN_VISION / TMAX / DC_SHELL if set.
#
# Usage:
#   ./run.sh pscan-synth | pscan-atpg | fullscan-synth | fullscan-atpg
#   ./run.sh metric | check
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

resolve_tool() {
  local var_name="$1"
  local default_name="$2"
  local override="${!var_name:-}"
  if [[ -n "$override" ]]; then
    echo "$override"
    return
  fi
  if command -v "$default_name" >/dev/null 2>&1; then
    command -v "$default_name"
    return
  fi
  echo ""
}

DESIGN_VISION="$(resolve_tool DESIGN_VISION design_vision)"
TMAX="$(resolve_tool TMAX tmax)"
DC_SHELL="$(resolve_tool DC_SHELL dc_shell)"

usage() {
  cat <<EOF
Usage: $0 <command>

  pscan-synth      Launch Design Vision; then source scripts/synthesis_pscan.tcl
  pscan-atpg       Launch TetraMAX; then source scripts/tmax_pscan.tcl
  fullscan-synth   Launch Design Vision; then source scripts/synthesis_fullscan.tcl
  fullscan-atpg    Launch TetraMAX; then source scripts/tmax_fullscan.tcl
  metric           Recompute M for data/exploration_results.csv
  check            Verify expected project files exist

Environment:
  SAED32_ROOT      Path to SAED32 EDK (required for synthesis / ATPG)
  DESIGN_VISION    Design Vision binary (default: first 'design_vision' on PATH)
  TMAX             TetraMAX binary     (default: first 'tmax' on PATH)
  DC_SHELL         Optional dc_shell   (default: first 'dc_shell' on PATH)

Current resolution:
  SAED32_ROOT=${SAED32_ROOT:-<unset>}
  DESIGN_VISION=${DESIGN_VISION:-<not found>}
  TMAX=${TMAX:-<not found>}
EOF
}

need_saed32() {
  if [[ -z "${SAED32_ROOT:-}" ]]; then
    echo "ERROR: SAED32_ROOT is not set." >&2
    echo "       export SAED32_ROOT=/path/to/saed32_edk" >&2
    echo "       (expects lib/stdcell_lvt/db_nldm and lib/stdcell_lvt/verilog)" >&2
    exit 1
  fi
  if [[ ! -d "$SAED32_ROOT" ]]; then
    echo "ERROR: SAED32_ROOT does not exist: $SAED32_ROOT" >&2
    exit 1
  fi
}

need_tool() {
  local label="$1"
  local path="$2"
  if [[ -z "$path" ]]; then
    echo "ERROR: $label not found." >&2
    echo "       Put it on PATH or set the matching env var (see ./run.sh with no args)." >&2
    exit 1
  fi
  if [[ ! -x "$path" ]] && ! command -v "$path" >/dev/null 2>&1; then
    echo "ERROR: $label is not executable: $path" >&2
    exit 1
  fi
}

case "${1:-}" in
  pscan-synth)
    need_saed32
    need_tool "Design Vision" "$DESIGN_VISION"
    echo "SAED32_ROOT=$SAED32_ROOT"
    echo "Starting Design Vision. Inside the tool run:"
    echo "  source scripts/synthesis_pscan.tcl"
    exec "$DESIGN_VISION"
    ;;
  pscan-atpg)
    need_saed32
    need_tool "TetraMAX" "$TMAX"
    echo "SAED32_ROOT=$SAED32_ROOT"
    echo "Starting TetraMAX. Inside the tool run:"
    echo "  source scripts/tmax_pscan.tcl"
    exec "$TMAX"
    ;;
  fullscan-synth)
    need_saed32
    need_tool "Design Vision" "$DESIGN_VISION"
    echo "SAED32_ROOT=$SAED32_ROOT"
    echo "Starting Design Vision. Inside the tool run:"
    echo "  source scripts/synthesis_fullscan.tcl"
    exec "$DESIGN_VISION"
    ;;
  fullscan-atpg)
    need_saed32
    need_tool "TetraMAX" "$TMAX"
    echo "SAED32_ROOT=$SAED32_ROOT"
    echo "Starting TetraMAX. Inside the tool run:"
    echo "  source scripts/tmax_fullscan.tcl"
    exec "$TMAX"
    ;;
  metric)
    python3 scripts/compute_m.py --table data/exploration_results.csv
    ;;
  check)
    missing=0
    for f in \
      rtl/b14.vhd \
      scripts/env.tcl \
      scripts/synthesis_pscan.tcl \
      scripts/tmax_pscan.tcl \
      scripts/synthesis_fullscan.tcl \
      scripts/tmax_fullscan.tcl \
      scripts/nonscan_ff_list.tcl \
      scripts/compute_m.py \
      results/b14_pscan.vg \
      results/b14_pscan.stil \
      results/b14_pattern_pscan.v
    do
      if [[ -e "$f" ]]; then
        echo "OK   $f"
      else
        echo "MISS $f"
        missing=1
      fi
    done
    if [[ -z "${SAED32_ROOT:-}" ]]; then
      echo "NOTE SAED32_ROOT is unset (required before synthesis/ATPG)"
    elif [[ -d "$SAED32_ROOT" ]]; then
      echo "OK   SAED32_ROOT=$SAED32_ROOT"
    else
      echo "MISS SAED32_ROOT path not found: $SAED32_ROOT"
      missing=1
    fi
    exit $missing
    ;;
  *)
    usage
    exit 1
    ;;
esac
