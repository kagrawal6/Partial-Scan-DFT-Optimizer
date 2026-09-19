# =============================================================================
# env.tcl — Shared environment for Design Compiler / Design Vision + TetraMAX
#
# Sourced by synthesis_*.tcl and tmax_*.tcl.
#
# Required before synthesis / ATPG:
#   export SAED32_ROOT=/path/to/saed32_edk
#   # expects:
#   #   $SAED32_ROOT/lib/stdcell_lvt/db_nldm/*.db
#   #   $SAED32_ROOT/lib/stdcell_lvt/verilog/saed32nm_lvt.v
# =============================================================================

if {![info exists PROJECT_ROOT]} {
    set PROJECT_ROOT [file normalize [file join [file dirname [info script]] ..]]
}

set RTL_DIR     [file join $PROJECT_ROOT rtl]
set RESULTS_DIR [file join $PROJECT_ROOT results]
set REPORTS_DIR [file join $PROJECT_ROOT reports]
set WORK_DIR    [file join $PROJECT_ROOT work]

file mkdir $RESULTS_DIR
file mkdir [file join $RESULTS_DIR fullscan]
file mkdir [file join $RESULTS_DIR pscan]
file mkdir [file join $REPORTS_DIR fullscan]
file mkdir [file join $REPORTS_DIR pscan]
file mkdir $WORK_DIR

# ---------------------------------------------------------------------------
# SAED32 EDK — must be provided via SAED32_ROOT
# ---------------------------------------------------------------------------
if {[info exists ::env(SAED32_ROOT)] && $::env(SAED32_ROOT) ne ""} {
    set SAED32_ROOT $::env(SAED32_ROOT)
} else {
    puts "ERROR: environment variable SAED32_ROOT is not set."
    puts "       export SAED32_ROOT=/path/to/saed32_edk"
    error "SAED32_ROOT unset"
}

set SAED32_DB_DIR  [file join $SAED32_ROOT lib stdcell_lvt db_nldm]
set SAED32_VLOG    [file join $SAED32_ROOT lib stdcell_lvt verilog saed32nm_lvt.v]

# Prefer a common TT corner; fall back through other known LVT NLDM names.
set CANDIDATE_LIBS {
    saed32lvt_tt1p05v25c.db
    saed32lvt_tt0p85v25c.db
    saed32lvt_tt1p05vn40c.db
    saed32lvt_ff1p16v25c.db
}

set TARGET_LIB ""
foreach lib $CANDIDATE_LIBS {
    if {[file exists [file join $SAED32_DB_DIR $lib]]} {
        set TARGET_LIB $lib
        break
    }
}

proc setup_dc_libraries {} {
    global SAED32_DB_DIR SAED32_ROOT TARGET_LIB RTL_DIR PROJECT_ROOT

    if {$TARGET_LIB eq ""} {
        puts "ERROR: No SAED32 LVT .db found under $SAED32_DB_DIR"
        puts "       Set SAED32_ROOT to your EDK install, e.g.:"
        puts "       setenv SAED32_ROOT /path/to/saed32_edk-2023"
        error "Missing target library"
    }

    set_app_var search_path [list . $RTL_DIR $SAED32_DB_DIR \
        [file join $SAED32_ROOT lib stdcell_lvt verilog] $PROJECT_ROOT]
    set_app_var target_library $TARGET_LIB
    set_app_var link_library   "* $TARGET_LIB"
    set_app_var synthetic_library dw_foundation.sldb

    puts "INFO: PROJECT_ROOT = $PROJECT_ROOT"
    puts "INFO: SAED32_ROOT  = $SAED32_ROOT"
    puts "INFO: target_library = $TARGET_LIB"
}

proc setup_dft_ports {} {
    # b14.vhd: clock, reset (active-high). Scan ports created by DFT Compiler.
    set_app_var test_default_period 100
    set_dft_signal -view existing_dft -type ScanClock -timing {45 55} -port clock
    set_dft_signal -view existing_dft -type Reset -active_state 1 -port reset
    set_dft_signal -view spec -type ScanDataIn  -port SERIAL_IN
    set_dft_signal -view spec -type ScanDataOut -port SERIAL_OUT
    set_dft_signal -view spec -type ScanEnable  -port SCAN_EN -active_state 1
}

puts "INFO: env.tcl loaded (PROJECT_ROOT=$PROJECT_ROOT)"
