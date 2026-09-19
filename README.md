# Partial-Scan Optimization — ITC'99 b14 (Viper Processor)

Maximize a composite DFT metric **M** on a synthesized processor by inserting a
**partial scan** chain instead of full scan: keep test coverage high enough,
cut area and especially pattern count, stay within ATE pin limits (≤ 2 chains).

Winning checked-in point (Partial 7): **1 chain**, K=20 FFs off-scan,
`set_atpg -coverage 75` → TC ≈ 75.1%, N = 32, **M ≈ 2064**.

See [`project_description.md`](project_description.md) for the full write-up.

## Layout

```
rtl/b14.vhd                 RTL (ITC'99)
scripts/                    DC + TetraMAX flow
  env.tcl                   Library / path setup (SAED32)
  synthesis_{full,p}scan.tcl
  tmax_{full,p}scan.tcl
  nonscan_ff_list.tcl       FFs excluded from scan (K=20)
  compute_m.py              Metric calculator
constraints/b14.sdc         Clock / IO constraints
results/                    Netlists, STIL, patterns
reports/                    Area / timing / scan reports
data/exploration_results.csv
docs/                       Problem statement + design report
```

## Requirements

| Dependency | Role |
|------------|------|
| Synopsys Design Vision or `dc_shell` | Synthesis + DFT Compiler scan insertion |
| Synopsys TetraMAX (`tmax`) | Stuck-at ATPG |
| SAED32 EDK (LVT) | Standard-cell `.db` + Verilog simulation models |
| Python 3 | Metric calculator only (`scripts/compute_m.py`) |

Point the flow at **your** installs with environment variables (required for the library path):

```bash
export SAED32_ROOT=/path/to/saed32_edk   # must contain lib/stdcell_lvt/...
export DESIGN_VISION=design_vision       # or absolute path to the binary
export TMAX=tmax                         # or absolute path to the binary
# optional if you prefer batch synthesis:
export DC_SHELL=dc_shell
```

`SAED32_ROOT` should look like:

```
$SAED32_ROOT/
  lib/stdcell_lvt/db_nldm/*.db
  lib/stdcell_lvt/verilog/saed32nm_lvt.v
```

`scripts/env.tcl` auto-picks the first available LVT NLDM corner under `db_nldm/`.
Override the corner by ensuring your preferred `.db` is first among the candidates it searches,
or edit `CANDIDATE_LIBS` in `scripts/env.tcl`.

## How to run

Always start from the **project root** so relative paths resolve.

### 0. Sanity checks (no Synopsys license needed)

```bash
chmod +x run.sh
./run.sh check
./run.sh metric
```

### 1. Configure the environment

```bash
export SAED32_ROOT=/path/to/saed32_edk
# Ensure design_vision (or dc_shell) and tmax are on PATH, or set:
export DESIGN_VISION=$(command -v design_vision)
export TMAX=$(command -v tmax)
```

### 2. Phase 2 — Partial scan (primary)

**Synthesis**

```bash
cd /path/to/Partial-Scan-Optimization-b14-Viper-Processor
design_vision
# or:  ./run.sh pscan-synth
```

Inside Design Vision / `dc_shell`:

```tcl
source scripts/synthesis_pscan.tcl
```

Produces:

- `results/pscan/b14_pscan.vg`
- `results/pscan/b14_pscan.stil`
- reports under `reports/pscan/`

**ATPG**

```bash
tmax
# or:  ./run.sh pscan-atpg
```

Inside TetraMAX:

```tcl
source scripts/tmax_pscan.tcl
```

Prints the Uncollapsed Stuck Fault Summary and Pattern Summary, and writes
`results/pscan/b14_pattern_pscan.v`.

Optional coverage exploration (same netlist, different ATPG stop):

```tcl
set COVERAGE_GOAL 85
source scripts/tmax_pscan.tcl
```

**Score M** (use TC / A / N / L from the tool reports):

```bash
python3 scripts/compute_m.py --tc 75.1 --area 8564.96247 --patterns 32 --length 195 --pins 3
```

### 3. Phase 1 — Full scan

Same workflow with the full-scan scripts:

```tcl
# In Design Vision:
source scripts/synthesis_fullscan.tcl

# In TetraMAX:
source scripts/tmax_fullscan.tcl
```

Or `./run.sh fullscan-synth` / `./run.sh fullscan-atpg`. Outputs go to `results/fullscan/`.

Root-level `synthesis_*.tcl` / `tmax_*.tcl` are thin wrappers that source `scripts/`.

## Winning configuration

| Item | Value |
|------|--------|
| Non-scan FFs | 20 highest-SCOAP (`scripts/nonscan_ff_list.tcl`) |
| Chains / pins P | 1 / 3 |
| Chain length L | 195 |
| ATPG coverage goal | 75 |
| TC / N / M | 75.1% / 32 / ~2064 |

Kept in scan (coverage-critical): `state_reg`, `IR_reg[23]`.
