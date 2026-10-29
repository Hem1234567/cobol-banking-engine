#!/usr/bin/env python3
"""Validate README links, documented commands, and required documentation."""

from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
README = ROOT / "README.md"

REQUIRED_DOCS = [
    "docs/ARCHITECTURE.md",
    "docs/COBOL_GUIDE.md",
    "docs/TEST_PLAN.md",
    "docs/MAINFRAME_MAPPING.md",
    "docs/SECURITY.md",
    "docs/KNOWN_LIMITATIONS.md",
    "docs/TROUBLESHOOTING.md",
    "docs/INTERVIEW_NOTES.md",
    "examples/jcl/README.md",
    "examples/jcl/BNKSAMPLE.jcl",
]

README_SECTIONS = [
    "## Overview",
    "## Features",
    "## Architecture",
    "## Repository Structure",
    "## Prerequisites",
    "## Build",
    "## Test",
    "## Demo",
    "## Transaction Rules",
    "## Financial Integrity",
    "## GitHub Actions",
    "## Verification Status",
    "## Mainframe Integration Status",
    "## Known Limitations",
    "## Interview Preparation",
]

DOC_SECTIONS = {
    "docs/ARCHITECTURE.md": ["## Program Responsibilities", "## Data Flow", "## Invariants"],
    "docs/COBOL_GUIDE.md": ["## PIC Clauses", "## COMP-3", "## File Status", "## CALL and Copybooks"],
    "docs/TEST_PLAN.md": ["## Test Strategy", "## Required Scenarios", "## Expected Sample Results"],
    "docs/MAINFRAME_MAPPING.md": ["## z/OS Concepts", "## JCL", "## Zowe", "## Differences"],
    "docs/SECURITY.md": ["## Data Policy", "## Credentials", "## CI Permissions"],
    "docs/KNOWN_LIMITATIONS.md": ["## Functional Limits", "## Portability Limits", "## Integration Status"],
    "docs/TROUBLESHOOTING.md": ["## Build Problems", "## Runtime Problems", "## CI Problems"],
    "docs/INTERVIEW_NOTES.md": ["## Short Project Explanation", "## Transaction Walkthroughs", "## Interview Questions"],
}

LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
DISALLOWED_CLAIMS = [
    re.compile(r"\bCI\s+is\s+(?:green|passing)\b", re.IGNORECASE),
    re.compile(r"\b(?:has been|was) (?:tested|deployed) on (?:a real )?z/OS\b",
               re.IGNORECASE),
]


def main() -> int:
    errors: list[str] = []
    if not README.exists():
        print("DOCS|FAIL|README.md is missing", file=sys.stderr)
        return 1
    readme_text = README.read_text(encoding="utf-8")

    for heading in README_SECTIONS:
        if heading.lower() not in readme_text.lower():
            errors.append(f"README.md is missing section {heading!r}")

    for command in ("./scripts/build.sh", "./scripts/test.sh", "./scripts/run_demo.sh"):
        if command not in readme_text:
            errors.append(f"README.md does not document {command}")

    for relative in REQUIRED_DOCS:
        path = ROOT / relative
        if not path.exists() or path.stat().st_size == 0:
            errors.append(f"missing or empty documentation file: {relative}")
            continue
        text = path.read_text(encoding="utf-8")
        for heading in DOC_SECTIONS.get(relative, []):
            if heading.lower() not in text.lower():
                errors.append(f"{relative} is missing section {heading!r}")

    for match in LINK_RE.finditer(readme_text):
        target = match.group(1).strip()
        if target.startswith("<") and target.endswith(">"):
            target = target[1:-1]
        if target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        target = target.split("#", 1)[0]
        if not target:
            continue
        resolved = (README.parent / target).resolve()
        if not resolved.exists():
            errors.append(f"README.md has a broken local link: {target}")

    for pattern in DISALLOWED_CLAIMS:
        if pattern.search(readme_text):
            errors.append(f"README.md contains a disallowed unverified claim: {pattern.pattern}")

    required_statements = [
        "not production",
        "has not been tested against a real IBM z/OS",
    ]
    lowered = readme_text.lower()
    for statement in required_statements:
        if statement.lower() not in lowered:
            errors.append(f"README.md must state that {statement!r}")

    for required in (
        "data/sample/accounts.dat",
        "data/sample/transactions.dat",
        "docs/KNOWN_LIMITATIONS.md",
        "docs/MAINFRAME_MAPPING.md",
    ):
        if required not in readme_text:
            errors.append(f"README.md does not mention {required}")

    if errors:
        for error in errors:
            print(f"DOCS|FAIL|{error}", file=sys.stderr)
        return 1
    print(f"DOCS|PASS|documents={len(REQUIRED_DOCS) + 1}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
