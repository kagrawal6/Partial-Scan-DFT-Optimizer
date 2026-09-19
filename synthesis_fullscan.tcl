# Thin wrapper — prefer: source scripts/synthesis_fullscan.tcl
set PROJECT_ROOT [file normalize [file dirname [info script]]]
source [file join $PROJECT_ROOT scripts synthesis_fullscan.tcl]
