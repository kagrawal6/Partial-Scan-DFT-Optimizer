# Thin wrapper — prefer: source scripts/tmax_fullscan.tcl
set PROJECT_ROOT [file normalize [file dirname [info script]]]
source [file join $PROJECT_ROOT scripts tmax_fullscan.tcl]
