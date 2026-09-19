# Basic timing constraints for b14 (Viper subset)
# Clock / reset names match rtl/b14.vhd

create_clock -name clock -period 10.0 [get_ports clock]
set_ideal_network [get_ports {clock reset}]
set_input_delay  0.5 -clock clock [remove_from_collection [all_inputs] [get_ports {clock reset}]]
set_output_delay 0.5 -clock clock [all_outputs]
