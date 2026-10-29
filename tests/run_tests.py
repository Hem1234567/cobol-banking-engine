#!/usr/bin/env python3
"""Compile COBOL unit tests and execute deterministic integration scenarios."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))

import banking_checks as bc  # noqa: E402

WORK = ROOT / "build" / "test-work"
RESULTS_JSON = ROOT / "build" / "test-results.json"
RESULTS_XML = ROOT / "build" / "test-results.xml"


@dataclass
class TestResult:
    name: str
    passed: bool
    detail: str = ""
    duration: float = 0.0
    output: str = ""
    tags: list[str] = field(default_factory=list)


class Harness:
    def __init__(self) -> None:
        self.results: list[TestResult] = []
        self.env = os.environ.copy()
        self.env["LC_ALL"] = "C"
        self.cobc = self._configure_toolchain()
        self.app = self._find_app()

    def _configure_toolchain(self) -> str | None:
        local = ROOT / ".tools" / "gnucobol"
        cobc = os.environ.get("BNK_COBC")
        local_cobc = local / "bin" / ("cobc.exe" if os.name == "nt" else "cobc")
        if local_cobc.exists():
            self.env["PATH"] = str(local / "bin") + os.pathsep + self.env.get("PATH", "")
            self.env["COB_CONFIG_DIR"] = str(local / "config")
            if not cobc:
                cobc = str(local_cobc)
        if not cobc:
            cobc = shutil.which("cobc")
        return cobc

    def _find_app(self) -> Path:
        for name in ("bnkapp.exe", "bnkapp"):
            candidate = ROOT / "build" / "bin" / name
            if candidate.exists():
                return candidate
        raise SystemExit("build/bin/bnkapp is missing; run scripts/build.sh first")

    def add(self, name: str, passed: bool, detail: str = "", duration: float = 0.0,
            output: str = "", tags: list[str] | None = None) -> None:
        self.results.append(TestResult(
            name=name,
            passed=passed,
            detail=detail,
            duration=duration,
            output=output,
            tags=tags or [],
        ))
        label = "PASS" if passed else "FAIL"
        print(f"{label}|{name}" + (f"|{detail}" if detail and not passed else ""), flush=True)

    def run_app(self, outdir: Path, accounts: Path, transactions: Path,
                run_id: str = "TESTRUN001") -> subprocess.CompletedProcess[str]:
        outdir.mkdir(parents=True, exist_ok=True)
        env = {key: value for key, value in self.env.items() if not key.startswith("BNK_")}
        env.update({
            "BNK_ACCOUNTS_FILE": accounts.as_posix(),
            "BNK_TRANSACTIONS_FILE": transactions.as_posix(),
            "BNK_OUTPUT_DIR": outdir.as_posix(),
            "BNK_RUN_ID": run_id,
            "BNK_PROCESS_DATE": "2026-01-15",
            "BNK_CURRENCY": "USD",
        })
        return subprocess.run(
            [str(self.app)],
            cwd=str(ROOT),
            env=env,
            text=True,
            encoding="utf-8",
            errors="replace",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=90,
            check=False,
        )

    def compile_unit_driver(self, driver: str, module: str,
                            output_name: str) -> tuple[bool, str, Path]:
        if not self.cobc:
            return False, "cobc was not found", Path()
        bindir = WORK / "bin"
        bindir.mkdir(parents=True, exist_ok=True)
        suffix = ".exe" if os.name == "nt" else ""
        output = bindir / f"{output_name}{suffix}"
        cmd = [
            self.cobc, "-x", "-free", "-Wall", "-Wextra",
            "-I", str(ROOT / "src" / "main" / "cobol" / "copy"),
            "-o", str(output),
            str(ROOT / "src" / "test" / "cobol" / driver),
            str(ROOT / "src" / "main" / "cobol" / module),
        ]
        completed = subprocess.run(
            cmd,
            cwd=str(ROOT),
            env=self.env,
            text=True,
            encoding="utf-8",
            errors="replace",
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=90,
            check=False,
        )
        combined = completed.stdout
        if completed.returncode != 0:
            return False, f"compile failed:\n{combined}", output
        if "warning:" in combined.lower():
            return False, f"compiler warnings:\n{combined}", output
        return True, combined, output

    def run_unit_driver(self, label: str, driver: str, module: str,
                        output_name: str) -> None:
        started = time.monotonic()
        compiled, compile_log, exe = self.compile_unit_driver(driver, module, output_name)
        if not compiled:
            self.add(f"unit/{label}/compile", False, compile_log, time.monotonic() - started)
            return
        completed = subprocess.run(
            [str(exe)],
            cwd=str(ROOT),
            env=self.env,
            text=True,
            encoding="utf-8",
            errors="replace",
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=60,
            check=False,
        )
        duration = time.monotonic() - started
        output = completed.stdout
        case_lines = [line for line in output.splitlines()
                      if line.startswith("PASS|") or line.startswith("FAIL|")]
        summary = next((line for line in output.splitlines()
                        if line.startswith("SUMMARY|")), "")
        if not case_lines or not summary:
            self.add(f"unit/{label}/execute", False,
                     f"missing unit test output (exit {completed.returncode})\n{output}",
                     duration)
            return
        failures = 0
        for line in case_lines:
            parts = line.split("|", 2)
            status = parts[0]
            name = f"unit/{label}/{parts[1]}" if len(parts) > 1 else f"unit/{label}/case"
            detail = parts[2] if len(parts) > 2 else ""
            passed = status == "PASS"
            if not passed:
                failures += 1
            self.add(name, passed, detail, duration / max(len(case_lines), 1), output)
        if completed.returncode != 0 or failures > 0 or "FAILURES=0000" not in summary:
            self.add(f"unit/{label}/summary", False,
                     f"driver exit {completed.returncode}; {summary}\n{output}", duration)

    def compile_and_run_units(self) -> None:
        self.run_unit_driver("BNKVALID", "TESTVALID.CBL", "BNKVALID.CBL", "testvalid")
        self.run_unit_driver("BNKPROC", "TESTPROC.CBL", "BNKPROC.CBL", "testproc")

    def run_integration_cases(self) -> None:
        sample_accounts = ROOT / "data" / "sample" / "accounts.dat"
        sample_transactions = ROOT / "data" / "sample" / "transactions.dat"

        # 1. Full sample batch: accepted and rejected paths, transfer ledger,
        #    account equations and report generation.
        case = WORK / "sample"
        shutil.rmtree(case, ignore_errors=True)
        out = case / "out"
        started = time.monotonic()
        completed = self.run_app(out, sample_accounts, sample_transactions, "SAMPLERUN1")
        try:
            if completed.returncode != 0:
                raise bc.VerificationError(
                    f"batch exit {completed.returncode}\nstdout:\n{completed.stdout}\n"
                    f"stderr:\n{completed.stderr}")
            if "implicit CLOSE" in completed.stderr:
                raise bc.VerificationError(f"implicit close warning:\n{completed.stderr}")
            bc.verify_success(out, sample_transactions, bc.SAMPLE_EXPECTED)
            self.add("integration/sample", True, duration=time.monotonic() - started)
        except Exception as exc:  # noqa: BLE001 - report every failure as a test failure
            self.add("integration/sample", False, str(exc),
                     time.monotonic() - started, completed.stdout + completed.stderr)

        # 2. A deposit larger than the current balance is valid; deposits do
        #    not require available funds, only accepted-transaction capacity.
        case = WORK / "large-deposit"
        shutil.rmtree(case, ignore_errors=True)
        large_accounts = case / "accounts.dat"
        bc.write_lines(large_accounts, [
            bc.account_line("ACC0000001", "CUST00000001", "A", "CH", "000001000.00"),
        ])
        large_txns = case / "transactions.dat"
        bc.write_lines(large_txns, [
            bc.transaction_line("TXN000000001", "DEPOSIT", "ACC0000001", "",
                                "+000005000.00"),
        ])
        out = case / "out"
        started = time.monotonic()
        completed = self.run_app(out, large_accounts, large_txns, "LARGEDEP01")
        try:
            if completed.returncode != 0:
                raise bc.VerificationError(f"large-deposit batch exit {completed.returncode}")
            summary = bc.verify_success(out, large_txns, {
                "input_records": 1,
                "accepted_count": 1,
                "rejected_count": 0,
                "account_count": 1,
                "exception_count": 0,
                "ledger_count": 1,
                "transfer_count": 0,
                "deposit_total": "5000.00",
                "withdrawal_total": "0.00",
                "accepted_total": "5000.00",
                "rejected_total": "0.00",
                "ledger_debits": "0.00",
                "ledger_credits": "5000.00",
                "opening_total": "1000.00",
                "closing_total": "6000.00",
                "net_movement": "5000.00",
                "accounts": {
                    "ACC0000001": {"opening": "1000.00", "closing": "6000.00",
                                   "debits": "0.00", "credits": "5000.00", "count": 1},
                },
            })
            if summary["accepted"][0]["amount"] != bc.Decimal("5000.00"):
                raise bc.VerificationError("large deposit amount mismatch")
            self.add("integration/large-deposit", True,
                     duration=time.monotonic() - started)
        except Exception as exc:  # noqa: BLE001
            self.add("integration/large-deposit", False, str(exc),
                     time.monotonic() - started, completed.stdout + completed.stderr)

        # 3. Empty transaction input must still settle and report cleanly.
        case = WORK / "empty"
        shutil.rmtree(case, ignore_errors=True)
        empty_accounts = case / "accounts.dat"
        empty_txns = case / "transactions.dat"
        bc.write_lines(empty_accounts, [
            bc.account_line("ACC0000001", "CUST00000001", "A", "CH", "000001000.00"),
            bc.account_line("ACC0000002", "CUST00000002", "A", "SV", "000000500.00"),
        ])
        bc.write_lines(empty_txns, [])
        out = case / "out"
        started = time.monotonic()
        completed = self.run_app(out, empty_accounts, empty_txns, "EMPTYRUN01")
        try:
            if completed.returncode != 0:
                raise bc.VerificationError(f"empty batch exit {completed.returncode}")
            summary = bc.verify_success(out, empty_txns, {
                "input_records": 0,
                "accepted_count": 0,
                "rejected_count": 0,
                "account_count": 2,
                "exception_count": 0,
                "ledger_count": 0,
                "transfer_count": 0,
                "deposit_total": "0.00",
                "withdrawal_total": "0.00",
                "transfer_total": "0.00",
                "accepted_total": "0.00",
                "rejected_total": "0.00",
                "ledger_debits": "0.00",
                "ledger_credits": "0.00",
                "opening_total": "1500.00",
                "closing_total": "1500.00",
                "net_movement": "0.00",
            })
            if summary["accepted_count"] != 0:
                raise bc.VerificationError("empty batch accepted records")
            self.add("integration/empty-transactions", True,
                     duration=time.monotonic() - started)
        except Exception as exc:  # noqa: BLE001
            self.add("integration/empty-transactions", False, str(exc),
                     time.monotonic() - started, completed.stdout + completed.stderr)

        # 3. Invalid account master records are rejected while valid records load.
        case = WORK / "invalid-accounts"
        shutil.rmtree(case, ignore_errors=True)
        invalid_accounts = case / "accounts.dat"
        bad_balance = (
            "ACC0000004".ljust(10)
            + "CUST00000004".ljust(12)
            + "A"
            + "CH"
            + "ABCDEFGHI.00"
        ).ljust(80)
        bc.write_lines(invalid_accounts, [
            bc.account_line("ACC0000001", "CUST00000001", "A", "CH", "000001000.00"),
            bc.account_line("BAD0000002", "CUST00000002", "A", "SV", "000000500.00"),
            bc.account_line("ACC0000001", "CUST00000099", "A", "CH", "000000200.00"),
            bad_balance,
        ])
        invalid_txns = case / "transactions.dat"
        bc.write_lines(invalid_txns, [
            bc.transaction_line("TXN000000001", "DEPOSIT", "ACC0000001", "", "+000000050.00"),
            bc.transaction_line("TXN000000002", "WITHDRAWAL", "ACC0000001", "", "+000002000.00"),
        ])
        out = case / "out"
        started = time.monotonic()
        completed = self.run_app(out, invalid_accounts, invalid_txns, "INVALIDRUN")
        try:
            if completed.returncode != 0:
                raise bc.VerificationError(f"invalid-account batch exit {completed.returncode}")
            summary = bc.verify_success(out, invalid_txns, {
                "input_records": 2,
                "accepted_count": 1,
                "rejected_count": 1,
                "account_count": 1,
                "exception_count": 3,
                "ledger_count": 1,
                "transfer_count": 0,
                "deposit_total": "50.00",
                "withdrawal_total": "0.00",
                "accepted_total": "50.00",
                "rejected_total": "2000.00",
                "opening_total": "1000.00",
                "closing_total": "1050.00",
                "net_movement": "50.00",
                "account_exception_codes": ["A0002", "A0003", "A0006"],
            })
            if summary["accounts"][0]["closing"] != bc.Decimal("1050.00"):
                raise bc.VerificationError("valid account closing balance is wrong")
            self.add("integration/invalid-accounts", True,
                     duration=time.monotonic() - started)
        except Exception as exc:  # noqa: BLE001
            self.add("integration/invalid-accounts", False, str(exc),
                     time.monotonic() - started, completed.stdout + completed.stderr)

        # 4. Over-long transaction records are reported safely as E0001.
        case = WORK / "overlong-transaction"
        shutil.rmtree(case, ignore_errors=True)
        over_accounts = case / "accounts.dat"
        bc.write_lines(over_accounts, [
            bc.account_line("ACC0000001", "CUST00000001", "A", "CH", "000001000.00"),
        ])
        over_txns = case / "transactions.dat"
        bc.write_lines(over_txns, [
            bc.transaction_line("TXN000000001", "DEPOSIT", "ACC0000001", "",
                                "+000000025.00") + "EXTRA-OVERLONG-DATA",
        ])
        out = case / "out"
        started = time.monotonic()
        completed = self.run_app(out, over_accounts, over_txns, "OVERRUN001")
        try:
            if completed.returncode != 0:
                raise bc.VerificationError(f"overlong batch exit {completed.returncode}")
            bc.verify_success(out, over_txns, {
                "input_records": 1,
                "accepted_count": 0,
                "rejected_count": 1,
                "account_count": 1,
                "exception_count": 0,
                "ledger_count": 0,
                "transfer_count": 0,
                "rejected_total": "25.00",
                "opening_total": "1000.00",
                "closing_total": "1000.00",
                "net_movement": "0.00",
                "rejected_codes": {"000001": "E0001"},
            })
            self.add("integration/overlong-transaction", True,
                     duration=time.monotonic() - started)
        except Exception as exc:  # noqa: BLE001
            self.add("integration/overlong-transaction", False, str(exc),
                     time.monotonic() - started, completed.stdout + completed.stderr)

        # 5. Missing transaction file: nonzero exit, failure marker, no success marker.
        case = WORK / "fatal-missing-transactions"
        shutil.rmtree(case, ignore_errors=True)
        missing_out = case / "out"
        started = time.monotonic()
        completed = self.run_app(missing_out, sample_accounts,
                                 case / "does-not-exist.dat", "FATALRUN01")
        try:
            if completed.returncode == 0:
                raise bc.VerificationError("missing input returned exit 0")
            if (missing_out / "run_status.dat").exists():
                raise bc.VerificationError("failed batch published run_status.dat")
            failure = bc.parse_key_values(missing_out / "run_failure.dat")
            if failure.get("status") != "FAILED":
                raise bc.VerificationError("failure marker does not say FAILED")
            if "implicit CLOSE" in completed.stderr:
                raise bc.VerificationError(f"implicit close warning:\n{completed.stderr}")
            self.add("integration/fatal-missing-transactions", True,
                     duration=time.monotonic() - started)
        except Exception as exc:  # noqa: BLE001
            self.add("integration/fatal-missing-transactions", False, str(exc),
                     time.monotonic() - started, completed.stdout + completed.stderr)

        # 6. Existing output set is refused without rewriting the successful run.
        case = WORK / "rerun"
        shutil.rmtree(case, ignore_errors=True)
        rerun_out = case / "out"
        first = self.run_app(rerun_out, sample_accounts, sample_transactions, "RERUNRUN01")
        try:
            if first.returncode != 0:
                raise bc.VerificationError("first rerun case batch failed")
            before = self.snapshot(rerun_out)
            second = self.run_app(rerun_out, sample_accounts, sample_transactions, "RERUNRUN01")
            if second.returncode == 0:
                raise bc.VerificationError("second run into existing output returned 0")
            after = self.snapshot(rerun_out)
            if before != after:
                raise bc.VerificationError("refused rerun modified existing output")
            self.add("integration/rerun-refused", True, duration=0.0)
        except Exception as exc:  # noqa: BLE001
            self.add("integration/rerun-refused", False, str(exc))

        # 7. The same inputs and run configuration produce byte-identical outputs.
        case = WORK / "determinism"
        shutil.rmtree(case, ignore_errors=True)
        first_out = case / "first"
        second_out = case / "second"
        started = time.monotonic()
        first = self.run_app(first_out, sample_accounts, sample_transactions, "DETERMIN01")
        second = self.run_app(second_out, sample_accounts, sample_transactions, "DETERMIN01")
        try:
            if first.returncode != 0 or second.returncode != 0:
                raise bc.VerificationError("determinism batch failed")
            if self.snapshot(first_out) != self.snapshot(second_out):
                raise bc.VerificationError("two identical runs are not byte-identical")
            self.add("integration/determinism", True,
                     duration=time.monotonic() - started)
        except Exception as exc:  # noqa: BLE001
            self.add("integration/determinism", False, str(exc),
                     time.monotonic() - started)

    @staticmethod
    def snapshot(directory: Path) -> dict[str, str]:
        snapshot: dict[str, str] = {}
        for path in sorted(directory.iterdir()):
            if path.is_file():
                snapshot[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
        return snapshot

    def write_results(self) -> None:
        failures = sum(1 for result in self.results if not result.passed)
        payload = {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "summary": {
                "tests": len(self.results),
                "failures": failures,
                "passed": len(self.results) - failures,
            },
            "tests": [
                {
                    "name": result.name,
                    "status": "passed" if result.passed else "failed",
                    "detail": result.detail,
                    "duration_seconds": round(result.duration, 4),
                }
                for result in self.results
            ],
        }
        RESULTS_JSON.parent.mkdir(parents=True, exist_ok=True)
        RESULTS_JSON.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

        suite = ET.Element("testsuite", {
            "name": "cobol-enterprise-banking",
            "tests": str(len(self.results)),
            "failures": str(failures),
            "errors": "0",
            "time": f"{sum(result.duration for result in self.results):.3f}",
        })
        for result in self.results:
            case = ET.SubElement(suite, "testcase", {
                "classname": "cobol-banking",
                "name": result.name,
                "time": f"{result.duration:.3f}",
            })
            if not result.passed:
                failure = ET.SubElement(case, "failure", {"message": result.detail[:500]})
                failure.text = result.detail
        ET.ElementTree(suite).write(RESULTS_XML, encoding="utf-8", xml_declaration=True)

    def finish(self) -> int:
        failures = sum(1 for result in self.results if not result.passed)
        self.write_results()
        print(f"SUMMARY|TESTS={len(self.results)}|FAILURES={failures}", flush=True)
        print(f"RESULTS|{RESULTS_JSON.as_posix()}", flush=True)
        print(f"JUNIT|{RESULTS_XML.as_posix()}", flush=True)
        return 1 if failures else 0


def main() -> int:
    harness = Harness()
    WORK.mkdir(parents=True, exist_ok=True)
    harness.compile_and_run_units()
    harness.run_integration_cases()
    return harness.finish()


if __name__ == "__main__":
    raise SystemExit(main())
