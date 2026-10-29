#!/usr/bin/env python3
"""Validate required repository structure and high-confidence secret hygiene."""

from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = [
    "README.md",
    "LICENSE",
    ".gitignore",
    ".editorconfig",
    ".github/workflows/ci.yml",
    "src/main/cobol/BNKMAIN.CBL",
    "src/main/cobol/BNKVALID.CBL",
    "src/main/cobol/BNKPROC.CBL",
    "src/main/cobol/BNKSETTL.CBL",
    "src/main/cobol/BNKRPT.CBL",
    "src/main/cobol/copy/ACCOUNT.cpy",
    "src/main/cobol/copy/TRANSACT.cpy",
    "src/main/cobol/copy/LEDGER.cpy",
    "src/main/cobol/copy/INTERFACES.cpy",
    "src/test/cobol/TESTVALID.CBL",
    "src/test/cobol/TESTPROC.CBL",
    "data/sample/accounts.dat",
    "data/sample/transactions.dat",
    "tests/run_tests.py",
    "tests/banking_checks.py",
    "tests/verify_demo.py",
    "scripts/build.sh",
    "scripts/test.sh",
    "scripts/run_demo.sh",
    "scripts/validate_yaml.py",
    "scripts/validate_repo.py",
    "scripts/validate_docs.py",
    "docs/ARCHITECTURE.md",
    "docs/COBOL_GUIDE.md",
    "docs/TEST_PLAN.md",
    "docs/MAINFRAME_MAPPING.md",
    "docs/SECURITY.md",
    "docs/KNOWN_LIMITATIONS.md",
    "docs/TROUBLESHOOTING.md",
    "docs/INTERVIEW_NOTES.md",
    "examples/jcl/BNKSAMPLE.jcl",
    "examples/jcl/README.md",
    "output/.gitkeep",
]

PROGRAMS = {
    "BNKMAIN.CBL": "BNKMAIN",
    "BNKVALID.CBL": "BNKVALID",
    "BNKPROC.CBL": "BNKPROC",
    "BNKSETTL.CBL": "BNKSETTL",
    "BNKRPT.CBL": "BNKRPT",
}

SECRET_PATTERNS = [
    ("GitHub token", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}\b")),
    ("GitHub fine-grained token", re.compile(r"\bgithub_pat_[A-Za-z0-9_]{40,}\b")),
    ("AWS access key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("private key", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
]

SCAN_SUFFIXES = {
    ".sh", ".py", ".yml", ".yaml", ".md", ".cbl", ".cpy", ".dat",
    ".jcl", ".json", ".txt", ".html", ".css", ".js",
}
EXCLUDED_PARTS = {".git", ".tools", "build", ".work", "output", "__pycache__"}


def main() -> int:
    errors: list[str] = []
    for relative in REQUIRED_FILES:
        path = ROOT / relative
        if not path.exists():
            errors.append(f"missing required path: {relative}")
        elif path.is_file() and path.stat().st_size == 0 and path.name != ".gitkeep":
            errors.append(f"required file is empty: {relative}")

    for filename, program_id in PROGRAMS.items():
        path = ROOT / "src/main/cobol" / filename
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8", errors="replace").upper()
        if f"PROGRAM-ID. {program_id}." not in text:
            errors.append(f"{filename} does not declare PROGRAM-ID {program_id}")

    accounts = ROOT / "data/sample/accounts.dat"
    transactions = ROOT / "data/sample/transactions.dat"
    if accounts.exists():
        account_lines = accounts.read_text(encoding="ascii", errors="replace").splitlines()
        if len(account_lines) < 2:
            errors.append("sample account file must contain at least two records")
        for number, line in enumerate(account_lines, start=1):
            if len(line) > 80:
                errors.append(f"accounts.dat line {number} is longer than 80 bytes")
    if transactions.exists():
        transaction_lines = transactions.read_text(
            encoding="ascii", errors="replace"
        ).splitlines()
        if len(transaction_lines) < 3:
            errors.append("sample transaction file must contain at least three records")
        for number, line in enumerate(transaction_lines, start=1):
            if len(line) > 80:
                errors.append(f"transactions.dat line {number} is longer than 80 bytes")

    ci = ROOT / ".github/workflows/ci.yml"
    if ci.exists():
        ci_text = ci.read_text(encoding="utf-8")
        if "continue-on-error" in ci_text:
            errors.append("required CI workflow must not use continue-on-error")
        if "permissions:" not in ci_text or "contents: read" not in ci_text:
            errors.append("required CI workflow must declare contents: read")

    for path in sorted(ROOT.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in SCAN_SUFFIXES:
            continue
        if any(part in EXCLUDED_PARTS for part in path.parts):
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for label, pattern in SECRET_PATTERNS:
            if pattern.search(text):
                errors.append(f"possible {label} in {path.relative_to(ROOT)}")

    if errors:
        for error in errors:
            print(f"REPO|FAIL|{error}", file=sys.stderr)
        return 1
    print(f"REPO|PASS|required_files={len(REQUIRED_FILES)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
