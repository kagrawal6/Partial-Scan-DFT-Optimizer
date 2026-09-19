# Thin wrapper — prefer: source scripts/tmax_pscan.tcl
set PROJECT_ROOT [file normalize [file dirname [info script]]]
source [file join $PROJECT_ROOT scripts tmax_pscan.tcl]
