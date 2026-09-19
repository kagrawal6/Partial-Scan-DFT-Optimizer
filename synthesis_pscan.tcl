# Thin wrapper — prefer: source scripts/synthesis_pscan.tcl
# Kept at repo root for assignment-style naming / muscle memory.
set PROJECT_ROOT [file normalize [file dirname [info script]]]
source [file join $PROJECT_ROOT scripts synthesis_pscan.tcl]
