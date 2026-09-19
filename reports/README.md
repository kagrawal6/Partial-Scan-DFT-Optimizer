# Reports directory

After synthesis, Design Vision writes area / timing / power / scan-path reports here:

- `fullscan/` — from `scripts/synthesis_fullscan.tcl`
- `pscan/` — from `scripts/synthesis_pscan.tcl`

These files are generated on the CAD machine and are not required to re-run ATPG if
`results/` already contains the `.vg` and `.stil` artifacts.
