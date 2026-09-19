#!/usr/bin/env python3
"""Compute the partial-scan figure of merit M.

    M = TC / ((A/K1) * (N/K2) * (L/K3) * (P/K4))

Constants (from full-scan baseline characteristics):
    K1 = 14233, K2 = 480, K3 = 215, K4 = 3

TC is the test-coverage *percentage* (e.g. 75.1), not a 0–1 fraction.
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

K1, K2, K3, K4 = 14233.0, 480.0, 215.0, 3.0


def compute_m(tc: float, area: float, patterns: float, length: float, pins: float) -> float:
    denom = (area / K1) * (patterns / K2) * (length / K3) * (pins / K4)
    if denom == 0:
        raise ValueError("denominator is zero — check A/N/L/P inputs")
    return tc / denom


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tc", type=float, help="Test coverage %% (e.g. 75.1)")
    parser.add_argument("--area", type=float, help="Post-DFT area A")
    parser.add_argument("--patterns", type=float, help="Pattern count N")
    parser.add_argument("--length", type=float, help="Max scan-chain length L")
    parser.add_argument("--pins", type=float, default=3.0, help="Extra ATE pins P (default 3)")
    parser.add_argument(
        "--table",
        type=Path,
        help="Optional CSV of exploration points to score (columns: name,tc,area,patterns,length,pins)",
    )
    args = parser.parse_args()

    if args.table:
        with args.table.open(newline="") as f:
            reader = csv.DictReader(f)
            print(f"{'name':<28} {'TC':>7} {'A':>12} {'N':>6} {'L':>5} {'P':>3} {'M':>12}")
            best_name, best_m = None, -1.0
            for row in reader:
                m = compute_m(
                    float(row["tc"]),
                    float(row["area"]),
                    float(row["patterns"]),
                    float(row["length"]),
                    float(row.get("pins", 3)),
                )
                mark = ""
                if m > best_m:
                    best_m, best_name = m, row["name"]
                print(
                    f"{row['name']:<28} {float(row['tc']):7.2f} {float(row['area']):12.3f} "
                    f"{float(row['patterns']):6.0f} {float(row['length']):5.0f} "
                    f"{float(row.get('pins', 3)):3.0f} {m:12.4f}{mark}"
                )
            print(f"\nBest M: {best_name} = {best_m:.4f}")
        return 0

    missing = [k for k in ("tc", "area", "patterns", "length") if getattr(args, k) is None]
    if missing:
        parser.error(f"missing required args: {', '.join('--'+m for m in missing)} (or use --table)")

    m = compute_m(args.tc, args.area, args.patterns, args.length, args.pins)
    print(f"TC={args.tc}  A={args.area}  N={args.patterns}  L={args.length}  P={args.pins}")
    print(f"M = {m:.6f}")
    if args.tc < 40.0:
        print("WARNING: TC is below the 40% floor required by the problem statement.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
