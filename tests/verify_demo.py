#!/usr/bin/env python3
"""Independently verify the published demo output against known expectations."""

from __future__ import annotations

from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))

import banking_checks as bc  # noqa: E402


def main(argv: list[str]) -> int:
    outdir = Path(argv[1]) if len(argv) > 1 else ROOT / "output" / "demo"
    transactions = ROOT / "data" / "sample" / "transactions.dat"
    if not outdir.is_dir():
        print(f"DEMO_VERIFY|FAIL|missing output directory {outdir}", file=sys.stderr)
        return 1
    try:
        summary = bc.verify_success(outdir, transactions, bc.SAMPLE_EXPECTED)
    except Exception as exc:  # noqa: BLE001 - verification reports all failures
        print(f"DEMO_VERIFY|FAIL|{exc}", file=sys.stderr)
        return 1

    print("DEMO_VERIFY|PASS")
    print(f"accounts={summary['account_count']} "
          f"accepted={summary['accepted_count']} "
          f"rejected={summary['rejected_count']} "
          f"ledger={summary['ledger_count']} "
          f"closing={summary['closing_total']} "
          f"reconciliation=BALANCED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
