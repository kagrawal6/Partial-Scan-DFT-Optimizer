# =============================================================================
# synthesis_pscan.tcl — Phase 2: partial-scan DFT insertion for b14
#
# Winning config (Partial 7): exclude K=20 highest-SCOAP FFs, 1 scan chain,
# compile_ultra -scan. ATPG coverage goal is set later in tmax_pscan.tcl.
#
# Run from the project root in Design Vision / dc_shell:
#   cd <project_root>
#   design_vision
#   source scripts/synthesis_pscan.tcl
# =============================================================================

set PROJECT_ROOT [file normalize [file join [file dirname [info script]] ..]]
source [file join $PROJECT_ROOT scripts env.tcl]
source [file join $PROJECT_ROOT scripts nonscan_ff_list.tcl]
setup_dc_libraries

define_design_lib WORK -path $WORK_DIR
analyze -format vhdl [file join $RTL_DIR b14.vhd]
elaborate b14
current_design b14
link
uniquify

create_clock -name clock -period 10 [get_ports clock]
set_ideal_network [get_ports {clock reset}]

compile

# ----- Partial scan: muxed-FF style, leave K FFs off-scan -----
set_scan_configuration -style multiplexed_flip_flop

# Exclude highest-SCOAP difficulty flip-flops (see nonscan_ff_list.tcl / docs)
set_scan_element false $NONSCAN_FF_LIST

# Always keep coverage-critical FFs in scan (do NOT add to NONSCAN_FF_LIST):
#   state_reg, IR_reg[23]

setup_dft_ports
create_test_protocol

# compile_ultra -scan materially reduces area vs compile -scan alone
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
set RPT [file join $REPORTS_DIR pscan]
report_area      > [file join $RPT area_b14_pscan.rpt]
report_timing    > [file join $RPT timing_b14_pscan.rpt]
report_power     > [file join $RPT power_b14_pscan.rpt]
report_scan_path -view existing_dft -chain all > [file join $RPT chain_b14_pscan.rep]
report_scan_path -view existing_dft -cell all  > [file join $RPT cell_b14_pscan.rep]

# ----- Write results -----
set OUT [file join $RESULTS_DIR pscan]
change_names -hierarchy -rule verilog
write -format verilog -hierarchy -out [file join $OUT b14_pscan.vg]
write -format ddc     -hierarchy -output [file join $OUT b14_pscan.ddc]
write_scan_def -output [file join $OUT b14_scan_pscan.def]
set_app_var test_stil_netlist_format verilog
write_test_protocol -output [file join $OUT b14_pscan.stil]

file copy -force [file join $OUT b14_pscan.vg]   [file join $RESULTS_DIR b14_pscan.vg]
file copy -force [file join $OUT b14_pscan.stil] [file join $RESULTS_DIR b14_pscan.stil]

puts "INFO: Partial-scan synthesis complete."
puts "INFO: Non-scan FFs (K=[llength $NONSCAN_FF_LIST]): $NONSCAN_FF_LIST"
puts "INFO: Netlist : [file join $OUT b14_pscan.vg]"
puts "INFO: STIL    : [file join $OUT b14_pscan.stil]"
