# =============================================================================
# synthesis_fullscan.tcl — Phase 1: full-scan DFT insertion for b14
#
# Run from the project root in Design Vision / dc_shell:
#   cd <project_root>
#   design_vision
#   source scripts/synthesis_fullscan.tcl
# =============================================================================

set PROJECT_ROOT [file normalize [file join [file dirname [info script]] ..]]
source [file join $PROJECT_ROOT scripts env.tcl]
setup_dc_libraries

define_design_lib WORK -path $WORK_DIR
analyze -format vhdl [file join $RTL_DIR b14.vhd]
elaborate b14
current_design b14
link
uniquify

# Basic constraints (clock name from RTL)
create_clock -name clock -period 10 [get_ports clock]
set_ideal_network [get_ports {clock reset}]

compile

# ----- Full scan: every flip-flop becomes a scan element -----
set_scan_configuration -style multiplexed_flip_flop
setup_dft_ports
create_test_protocol

compile_ultra -scan
compile -scan
preview_dft
dft_drc

set_scan_configuration -chain_count 1
set_scan_configuration -clock_mixing no_mix
set_scan_path chain1 -scan_data_in SERIAL_IN -scan_data_out SERIAL_OUT
insert_dft
set_scan_state scan_existing

# ----- Reports -----
set RPT [file join $REPORTS_DIR fullscan]
report_area      > [file join $RPT area_b14_fullscan.rpt]
report_timing    > [file join $RPT timing_b14_fullscan.rpt]
report_power     > [file join $RPT power_b14_fullscan.rpt]
report_scan_path -view existing_dft -chain all > [file join $RPT chain_b14_fullscan.rep]
report_scan_path -view existing_dft -cell all  > [file join $RPT cell_b14_fullscan.rep]

# ----- Write results -----
set OUT [file join $RESULTS_DIR fullscan]
change_names -hierarchy -rule verilog
write -format verilog -hierarchy -out [file join $OUT b14_fullscan.vg]
write -format ddc     -hierarchy -output [file join $OUT b14_fullscan.ddc]
write_scan_def -output [file join $OUT b14_scan_fullscan.def]
set_app_var test_stil_netlist_format verilog
write_test_protocol -output [file join $OUT b14_fullscan.stil]

# Convenience copies at results/ (assignment-style names)
file copy -force [file join $OUT b14_fullscan.vg]   [file join $RESULTS_DIR b14_fullscan.vg]
file copy -force [file join $OUT b14_fullscan.stil] [file join $RESULTS_DIR b14_fullscan.stil]

puts "INFO: Full-scan synthesis complete."
puts "INFO: Netlist : [file join $OUT b14_fullscan.vg]"
puts "INFO: STIL    : [file join $OUT b14_fullscan.stil]"
