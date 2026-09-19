# =============================================================================
# tmax_pscan.tcl — Phase 2: TetraMAX ATPG for partial-scan b14
#
# Winning config uses set_atpg -coverage 75 (Partial 7: TC≈75.1%, N=32).
# Override COVERAGE_GOAL before sourcing to explore other points, e.g.:
#   set COVERAGE_GOAL 85
#   source scripts/tmax_pscan.tcl
#
# Run from the project root in TetraMAX:
#   cd <project_root>
#   tmax
#   source scripts/tmax_pscan.tcl
# =============================================================================

set PROJECT_ROOT [file normalize [file join [file dirname [info script]] ..]]
source [file join $PROJECT_ROOT scripts env.tcl]

if {![info exists COVERAGE_GOAL]} {
    set COVERAGE_GOAL 75
}

if {![file exists $SAED32_VLOG]} {
    puts "ERROR: SAED32 Verilog library not found: $SAED32_VLOG"
    puts "       Set SAED32_ROOT to your EDK install."
    exit 1
}

set NETLIST [file join $RESULTS_DIR pscan b14_pscan.vg]
set STIL    [file join $RESULTS_DIR pscan b14_pscan.stil]
set PATOUT  [file join $RESULTS_DIR pscan b14_pattern_pscan.v]

# Fall back to checked-in results/ copies if pscan/ subdir was not regenerated
if {![file exists $NETLIST] && [file exists [file join $RESULTS_DIR b14_pscan.vg]]} {
    set NETLIST [file join $RESULTS_DIR b14_pscan.vg]
}
if {![file exists $STIL] && [file exists [file join $RESULTS_DIR b14_pscan.stil]]} {
    set STIL [file join $RESULTS_DIR b14_pscan.stil]
}

if {![file exists $NETLIST]} {
    puts "ERROR: Missing netlist — run scripts/synthesis_pscan.tcl first."
    exit 1
}
if {![file exists $STIL]} {
    puts "ERROR: Missing STIL — run scripts/synthesis_pscan.tcl first."
    exit 1
}

read_netlist $SAED32_VLOG
read_netlist $NETLIST
run_build_model b14

set_drc $STIL
run_drc

add_faults -all

set_atpg -merge high
set_atpg -abort_limit 350
set_atpg -coverage $COVERAGE_GOAL
set_faults -fault_coverage

run_atpg -auto_compression

system "rm -f $PATOUT"
write_patterns $PATOUT -internal -format binary
file copy -force $PATOUT [file join $RESULTS_DIR b14_pattern_pscan.v]

report_faults -summary
report_patterns -all

puts "INFO: Partial-scan ATPG complete (coverage goal = $COVERAGE_GOAL)."
puts "INFO: Patterns: $PATOUT"
puts "INFO: Review Uncollapsed Stuck Fault Summary + Pattern Summary above."
puts "INFO: Compute M with: python3 scripts/compute_m.py --tc <TC> --area <A> --patterns <N> --length <L> --pins 3"
