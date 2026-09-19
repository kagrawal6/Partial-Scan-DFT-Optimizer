# =============================================================================
# tmax_fullscan.tcl — Phase 1: TetraMAX ATPG for full-scan b14
#
# Run from the project root in TetraMAX:
#   cd <project_root>
#   tmax
#   source scripts/tmax_fullscan.tcl
# =============================================================================

set PROJECT_ROOT [file normalize [file join [file dirname [info script]] ..]]
source [file join $PROJECT_ROOT scripts env.tcl]

if {![file exists $SAED32_VLOG]} {
    puts "ERROR: SAED32 Verilog library not found: $SAED32_VLOG"
    puts "       Set SAED32_ROOT to your EDK install."
    exit 1
}

set NETLIST [file join $RESULTS_DIR fullscan b14_fullscan.vg]
set STIL    [file join $RESULTS_DIR fullscan b14_fullscan.stil]
set PATOUT  [file join $RESULTS_DIR fullscan b14_pattern_fullscan.v]

if {![file exists $NETLIST]} {
    puts "ERROR: Missing $NETLIST — run scripts/synthesis_fullscan.tcl first."
    exit 1
}
if {![file exists $STIL]} {
    puts "ERROR: Missing $STIL — run scripts/synthesis_fullscan.tcl first."
    exit 1
}

read_netlist $SAED32_VLOG
read_netlist $NETLIST
run_build_model b14

set_drc $STIL
run_drc

add_faults -all

# Economical full-scan ATPG: high merge + auto compression
set_atpg -merge high
set_atpg -abort_limit 350
set_faults -fault_coverage

run_atpg -auto_compression

system "rm -f $PATOUT"
write_patterns $PATOUT -internal -format binary
file copy -force $PATOUT [file join $RESULTS_DIR b14_pattern_fullscan.v]

report_faults -summary
report_patterns -all

puts "INFO: Full-scan ATPG complete."
puts "INFO: Patterns: $PATOUT"
puts "INFO: Review Uncollapsed Stuck Fault Summary + Pattern Summary above."
