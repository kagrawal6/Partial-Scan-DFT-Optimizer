# Project Description — Partial-Scan Optimization of ITC'99 b14

This document explains **what** this repository does, **why** each piece exists, and
**how** the full-scan and partial-scan flows interact with the metric being optimized.

For a short overview and run commands, see [`README.md`](README.md).
The original problem statement is in [`docs/S25-project.pdf`](docs/S25-project.pdf).
The design exploration write-up is in [`docs/Agrawal.pdf`](docs/Agrawal.pdf).

---

## 1. Problem statement

Given the ITC'99 **b14** RTL (a Viper processor subset), build two DFT flows:

1. **Full scan** — every flip-flop is a scan flip-flop; generate an economical stuck-at
   test set with TetraMAX.
2. **Partial scan** — leave some flip-flops off-scan to **maximize** the figure of merit

\[
M = \frac{\mathrm{TC}}{\left(\frac{A}{K_1}\right)\left(\frac{N}{K_2}\right)\left(\frac{L}{K_3}\right)\left(\frac{P}{K_4}\right)}
\]

with constants taken from full-scan characteristics:

| Constant | Value | Normalizes |
|----------|-------|------------|
| \(K_1\) | 14233 | Area \(A\) |
| \(K_2\) | 480 | Pattern count \(N\) |
| \(K_3\) | 215 | Max chain length \(L\) |
| \(K_4\) | 3 | Extra ATE pins \(P\) |

**Symbols**

| Symbol | Meaning | Source |
|--------|---------|--------|
| **TC** | Test coverage (%) from TetraMAX | ATPG report |
| **A** | Area after scan insertion | Design Vision `report_area` |
| **N** | Number of test patterns | ATPG Pattern Summary |
| **L** | Length of the longest scan chain | Design Vision scan-path report |
| **P** | Extra pins; **3 per chain** (SI, SO, SE) | Design choice |

**Hard constraints**

- At most **2** scan chains (ATE pin budget).
- Test coverage **TC ≥ 40%**.
- Higher \(M\) is better. Full scan lands near \(M \approx 100\); partial scan should beat that
  by shrinking \(A\), \(N\), and/or \(L\) faster than TC falls.

**Intuition:** \(L \times N\) estimates ATE cycles (shift cost × pattern count). Partial scan
trades some coverage for fewer scan cells (smaller \(A\), shorter \(L\)) and often fewer
patterns. The winning knob in this project was not only *which* flops leave the chain, but
also **when ATPG stops** (`set_atpg -coverage`).

---

## 2. Design under test

| Item | Value |
|------|--------|
| Benchmark | ITC'99 **b14** — Viper processor (subset) |
| RTL | [`rtl/b14.vhd`](rtl/b14.vhd) (Politecnico di Torino / I99T) |
| Clock | `clock` (rising edge) |
| Reset | `reset`, **active-high** (`reset = '1'`) |
| Functional I/O | `datai`, `addr`, `datao`, `rd`, `wr` |
| DFT I/O (added) | `SERIAL_IN`, `SERIAL_OUT`, `SCAN_EN` |

Important registers that appear in SCOAP / scan decisions include `IR`, `state`, `reg0–reg3`,
`reg1`, `B`, `d`, `wr`, `rd`. Coverage collapses if `state_reg` or `IR_reg[23]` leave the chain.

---

## 3. End-to-end flow

```
rtl/b14.vhd
      │
      ▼
┌─────────────────────────────┐
│ Design Vision / DC          │
│  analyze → elaborate        │
│  compile                    │
│  set_scan_* / DFT signals   │
│  compile_ultra -scan        │
│  insert_dft                 │
│  write .vg + .stil + reports│
└──────────────┬──────────────┘
               │
               ▼
   results/{fullscan|pscan}/
     b14_*.vg   (gate netlist, SAED32 LVT)
     b14_*.stil (test protocol: chains, timing)
               │
               ▼
┌─────────────────────────────┐
│ TetraMAX                    │
│  read SAED32 Verilog + .vg  │
│  build model → DRC (.stil)  │
│  add_faults -all            │
│  run_atpg -auto_compression │
│  write_patterns (binary)    │
└──────────────┬──────────────┘
               │
               ▼
   b14_pattern_*.v
   + TC, N from on-screen summaries
               │
               ▼
   scripts/compute_m.py  →  M
```

Shared environment ([`scripts/env.tcl`](scripts/env.tcl)):

- Resolves `PROJECT_ROOT`, creates `results/`, `reports/`, `work/`.
- Points Design Compiler / TetraMAX at your **SAED32 LVT** EDK via `SAED32_ROOT`
  (must be set in the environment before sourcing the TCL scripts).
- Defines DFT ports: scan clock on `clock` (100 ns period, 45/55 ns pulse), active-high
  `reset`, and `SERIAL_IN` / `SERIAL_OUT` / `SCAN_EN`.

---

## 4. Phase 1 — Full scan

**Scripts:** [`scripts/synthesis_fullscan.tcl`](scripts/synthesis_fullscan.tcl),
[`scripts/tmax_fullscan.tcl`](scripts/tmax_fullscan.tcl).

### Synthesis behavior

1. Read and elaborate `b14.vhd`.
2. Compile to gates (SAED32 LVT).
3. Configure **multiplexed flip-flop** scan; **do not** mark any cell non-scan.
4. Create test protocol; `compile_ultra -scan` / `compile -scan`; DRC; **one** chain;
   `insert_dft`.
5. Emit:
   - `results/fullscan/b14_fullscan.vg`
   - `results/fullscan/b14_fullscan.stil`
   - area / timing / power / scan-path reports under `reports/fullscan/`

Full scan puts **all** FFs on the chain (baseline \(L\) and \(A\) near the \(K_*\) normalizers).

### ATPG behavior

1. Read SAED32 cell models + full-scan netlist; build model `b14`.
2. DRC against the STIL protocol.
3. `add_faults -all` (stuck-at).
4. High merge effort, abort limit 350, auto compression — aim for high TC with a compact
   pattern set (economical, not necessarily minimum \(N\)).
5. Write `results/fullscan/b14_pattern_fullscan.v` (binary, internal scan format).

Full-scan \(M\) is expected near **100** by construction of the \(K_*\) constants.

---

## 5. Phase 2 — Partial scan (focus of this repo)

**Scripts:** [`scripts/synthesis_pscan.tcl`](scripts/synthesis_pscan.tcl),
[`scripts/tmax_pscan.tcl`](scripts/tmax_pscan.tcl),
[`scripts/nonscan_ff_list.tcl`](scripts/nonscan_ff_list.tcl).

### 5.1 Selecting which flip-flops leave the chain

Method used (see also `docs/Agrawal.pdf`):

1. **SCOAP ranking** — synthesize full scan, dump TetraMAX controllability/observability
   (`CC0`, `CC1`, `CO`) via `report_primitives -all`, form \(D = CC0 + CC1 + CO\), sort
   easiest → hardest.
2. **Try both ends** — candidate \(K\)-sets from lowest-SCOAP *and* highest-SCOAP regions
   (not only “hardest flops”).
3. **Lock coverage-critical FFs** — excluding `state_reg` or `IR_reg[23]` dropped TC to ~30%.
   They stay on-scan regardless of SCOAP rank.
4. **Register balancing** — avoid dumping an entire wide register in or out; sample across
   registers when exploring \(K\).
5. **Winning set** — **K = 20 highest-SCOAP** FFs excluded via `set_scan_element false`
   (list in `scripts/nonscan_ff_list.tcl`):

   - `reg1_reg[3]` … `reg1_reg[19]`
   - `B_reg`
   - `d_reg[0]`, `d_reg[1]`

In the gate netlist those cells remain plain `DFFARX2_LVT`; scanned cells are `SDFFARX2_LVT`
with `.SI` / `.SE(SCAN_EN)`.

### 5.2 How many flops / how many chains / ATPG stop

Exploration loop: **edit \(K\)-set → synthesize → ATPG → compute \(M\)** until \(M\) peaks.

| Lever | Finding |
|-------|---------|
| Chain count | **1 chain always beat 2** — extra chain raises \(P\) more than it helps \(N\) |
| `compile_ultra -scan` | Much lower area than `compile -scan` alone (Partial 2 vs others) |
| Coverage goal | Dominant lever: same netlist, lower `set_atpg -coverage` → fewer patterns → higher \(M\) |
| \(K\) | 20 was better than 10 or 30 in the explored set |

Checked-in ATPG uses **`set_atpg -coverage 75`** (Partial 7). Override before sourcing:

```tcl
set COVERAGE_GOAL 85
source scripts/tmax_pscan.tcl
```

### 5.3 Exploration table (source of truth)

Reproduced from the design report; also in [`data/exploration_results.csv`](data/exploration_results.csv).
Recompute with `./run.sh metric`.

| Point | Policy | TC | A | N | L | Scan FFs | M |
|-------|--------|----|---|---|---|----------|---|
| P1 | K=10 low SCOAP, no cap | 95.57 | 7589.7 | 254 | 205 | 205 | 355 |
| P2 | K=20 high, no `compile_ultra` | 89.32 | 11863.2 | 257 | 195 | 195 | 221 |
| P3 | K=20 low, no cap | 91.1 | 8565.8 | 241 | 195 | 205* | 332 |
| P4 | K=20 low, cov 85 | 85.93 | 8565.8 | 64 | 195 | 195 | 1181 |
| P5 | K=20 high, cov 85 | 86.68 | 8565.0 | 64 | 195 | 195 | 1191 |
| P6 | K=20 low + drop wr/rd, cov 85 | 86.62 | 8565.6 | 96 | 195 | 195 | 793 |
| **P7** | **K=20 high, cov 75** | **75.1** | **8565.0** | **32** | **195** | **195** | **2064** |
| P8 | K=30 low, no cap | 85.98 | 7518.1 | 178 | 185 | 185 | 510 |

\*P3 scan-FF count in the original table is listed as 205; chain length is 195 — treat L as the
authoritative shift length for \(M\). All points use **P = 3**, **1 chain**.

**Best column: Partial 7** — matches the checked-in netlist / STIL / patterns / scripts.

### 5.4 Why coverage capping raises \(M\) so much

Same K=20 netlist:

| ATPG stop | TC | N | Approx. M |
|-----------|----|---|-----------|
| No goal | ~91% | 241 | ~332 |
| Coverage 85 | ~86% | 64 | ~1180 |
| Coverage 75 | ~75% | 32 | ~2064 |

Denominator shrinks roughly with \(N\). As long as TC stays above 40%, stopping ATPG early
is a valid (and here optimal) tradeoff under this metric.

---

## 6. Artifacts in this repository

| Path | Role |
|------|------|
| `rtl/b14.vhd` | Source RTL |
| `scripts/env.tcl` | Paths + SAED32 + DFT port helpers |
| `scripts/synthesis_*.tcl` | Full / partial scan insertion |
| `scripts/tmax_*.tcl` | Stuck-at ATPG |
| `scripts/nonscan_ff_list.tcl` | Editable non-scan set |
| `scripts/compute_m.py` | Metric calculator |
| `constraints/b14.sdc` | Clock / IO constraints reference |
| `results/pscan/*` | Golden partial-scan `.vg`, `.stil`, patterns |
| `results/b14_pscan.*` | Same artifacts at assignment-style names |
| `data/exploration_results.csv` | Eight design points |
| `docs/S25-project.pdf` | Problem statement |
| `docs/Agrawal.pdf` | Selection + exploration report |
| `run.sh` | Launcher / `check` / `metric` |

Root-level `synthesis_*.tcl` and `tmax_*.tcl` are **wrappers** that `source` the scripts under
`scripts/` so either path works.

---

## 7. How to regenerate / explore

From the project root on any machine with Synopsys tools + SAED32:

```bash
export SAED32_ROOT=/path/to/saed32_edk
export DESIGN_VISION=$(command -v design_vision)   # optional if already on PATH
export TMAX=$(command -v tmax)                     # optional if already on PATH

# Sanity (no licenses needed)
./run.sh check
./run.sh metric

# Partial scan (primary)
./run.sh pscan-synth          # then: source scripts/synthesis_pscan.tcl
./run.sh pscan-atpg           # then: source scripts/tmax_pscan.tcl

# Full scan
./run.sh fullscan-synth
./run.sh fullscan-atpg
```

You can also launch `design_vision` / `tmax` yourself and `source` the scripts under
`scripts/` from the project root — `run.sh` is only a convenience wrapper.

To try a new \(K\)-set: edit `scripts/nonscan_ff_list.tcl`, re-run synthesis + ATPG, then:

```bash
python3 scripts/compute_m.py --tc <TC> --area <A> --patterns <N> --length <L> --pins 3
```

---

## 8. Interpreting tool outputs

**Design Vision (after `insert_dft`)**

- `report_area` → \(A\)
- `report_scan_path -chain all` → chain count and \(L\)
- Written STIL `ScanStructures` also records `ScanLength` (195 for the winning point)

**TetraMAX (after `run_atpg`)**

- Uncollapsed Stuck Fault Summary → **Test Coverage** (TC)
- Pattern Summary → **N**
- Binary patterns: `write_patterns … -internal -format binary` for external replay

**STIL** (IEEE 1450) is the test protocol: pin roles, waveforms, scan chain, load/unload.
TetraMAX consumes it for DRC; it is not a programming language.

---

## 9. Design decisions worth remembering

1. **One chain** under a pin-aware metric — \(P\) is linear in chain count.
2. **SCOAP is a guide**, not a proof — both ends of the ranking were measured; the best \(M\)
   used high-SCOAP exclusion *plus* a coverage cap.
3. **Do not exclude `state_reg` / `IR_reg[23]`** — coverage floor fails.
4. **`compile_ultra -scan`** is required for competitive area.
5. **`set_atpg -coverage`** is the largest \(M\) lever once the netlist is fixed.
6. Dropping `wr_reg`/`rd_reg` (Partial 6) **hurt** \(N\) and \(M\) in this design — the
   winning netlist keeps them on-scan.

---

## 10. License / attribution

- `rtl/b14.vhd` is from the ITC'99 / I99T benchmark suite (Politecnico di Torino).
- SAED32 libraries are Synopsys EDK collateral available on the host CAD environment; they
  are **not** redistributed in this repository.
