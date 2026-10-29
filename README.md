# COBOL Enterprise Banking and Settlement Engine

A working, deterministic **GnuCOBOL batch banking simulator**: account master
loading, transaction validation, deposits, withdrawals, account-to-account
transfers, an auditable ledger, end-of-day settlement, reconciliation, and
report generation. The project is designed as a technical portfolio and
interview walkthrough for enterprise COBOL and IBM Z concepts.

> **Scope and honesty:** this is a fictional learning and portfolio project. It
> is **not production-ready**, **not certified** for banking or regulatory use,
> and **has not been tested against a real IBM z/OS system**. Local GnuCOBOL
> execution does not prove compilation or execution on z/OS.

## Overview

The batch reads an account master file and a daily transaction file, validates
every transaction, applies accepted movements to in-memory `COMP-3` balances,
and writes:

- accepted and rejected transaction files;
- a double-entry ledger for every accepted movement;
- an end-of-day account summary;
- machine-readable settlement and reconciliation controls;
- human-readable daily, account, exception, settlement, and reconciliation
  reports;
- a success marker **only after** independent reconciliation and report
  generation pass.

All example data is fictional. No network, database, mainframe, bank account, or
credential is required for the standard build and test suite.

## Features

- Five production COBOL programs with separate responsibilities.
- Copybooks for the account, transaction, ledger, and CALL interfaces.
- Exact decimal money using `PIC S9(9)V99 COMP-3`; no binary floating point.
- `DEPOSIT`, `WITHDRAWAL`, and `TRANSFER` processing in input order.
- Unsupported types, duplicate ids, malformed records, closed accounts,
  unknown accounts, self-transfers, non-positive amounts, and insufficient
  funds are rejected with stable error codes.
- A rejected transaction performs no account-table update.
- Every transfer produces one `DEBIT` and one equal `CREDIT` ledger entry.
- Independent settlement recomputes counts and totals from output records.
- Per-account and aggregate reconciliation checks.
- Staged demo publication: output is moved to `output/demo` only after
  independent verification succeeds.
- A run lock and success marker prevent accidental replay into an existing
  output directory.
- 28 portable COBOL unit cases plus 8 Python-driven integration scenarios
  (36 test results in the current harness).
- GitHub Actions workflow with validation, build, tests, end-to-end demo, and
  documentation jobs.
- A separate, optional z/OS **upload** workflow that is intentionally not part
  of required CI and is documented as unverified.

## Architecture

```text
accounts.dat ──> BNKMAIN ──> BNKVALID ──> BNKPROC ──> accepted.dat
                    │            │            │            ledger.dat
transactions.dat ───┘            │            └──────────> rejected.dat
                                  │                         account_exceptions.dat
                                  └── account table         accounts_out.dat
                                                            batch_control.dat

BNKMAIN ──CALL──> BNKSETTL ──> settlement.dat
                               reconciliation.dat

BNKMAIN ──CALL──> BNKRPT ──> five text reports

batch passes all checks ──> run_status.dat (SUCCESS)
batch fails              ──> run_failure.dat (FAILED), nonzero exit
```

| Program | Responsibility |
|---|---|
| `BNKMAIN.CBL` | Batch control, sequential input, account/transaction tables, output files, run lock, publication gate |
| `BNKVALID.CBL` | Transaction id/type/amount/account/funds validation; no file I/O, no balance changes |
| `BNKPROC.CBL` | Atomic balance application and ledger-entry creation for accepted transactions |
| `BNKSETTL.CBL` | Independent settlement, ledger linking, account equations, control totals, reconciliation |
| `BNKRPT.CBL` | Deterministic text reports rendered from batch outputs |

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the complete data flow,
CALL interfaces, file lifecycle, and invariants.

## Repository Structure

```text
.
├── .github/workflows/
│   ├── ci.yml                     # required credential-free CI
│   └── zos-integration.yml        # optional, unverified upload workflow
├── data/
│   ├── expected/sample_expected.txt
│   └── sample/
│       ├── accounts.dat           # fixed 80-byte fictional account records
│       └── transactions.dat       # fixed/short records covering all outcomes
├── docs/
│   ├── ARCHITECTURE.md
│   ├── COBOL_GUIDE.md
│   ├── INTERVIEW_NOTES.md
│   ├── KNOWN_LIMITATIONS.md
│   ├── MAINFRAME_MAPPING.md
│   ├── SECURITY.md
│   ├── TEST_PLAN.md
│   └── TROUBLESHOOTING.md
├── examples/jcl/                  # illustrative z/OS JCL, not runnable locally
├── scripts/
│   ├── build.sh
│   ├── run_demo.sh
│   ├── test.sh
│   ├── validate_docs.py
│   ├── validate_repo.py
│   └── validate_yaml.py
├── src/main/cobol/
│   ├── BNKMAIN.CBL
│   ├── BNKPROC.CBL
│   ├── BNKRPT.CBL
│   ├── BNKSETTL.CBL
│   ├── BNKVALID.CBL
│   └── copy/{ACCOUNT,TRANSACT,LEDGER,INTERFACES}.cpy
├── src/test/cobol/
│   ├── TESTPROC.CBL
│   └── TESTVALID.CBL
├── tests/
│   ├── banking_checks.py          # independent output parsers and invariants
│   ├── run_tests.py
│   └── verify_demo.py
├── LICENSE
├── README.md
└── output/.gitkeep
```

Compiled binaries, temporary workspaces, and generated demo output are ignored
by Git.

## Prerequisites

- GnuCOBOL 3.1.2 or newer; **verified locally with GnuCOBOL 3.2.0**.
- Bash (Linux, macOS, WSL, or Git Bash on Windows).
- Python 3.10 or newer for the test and documentation tooling.
- Optional: `shellcheck` and PyYAML for local workflow validation.

No Python packages are required for the COBOL build or the test harness. PyYAML
is required only by `scripts/validate_yaml.py`.

### Ubuntu

```bash
sudo apt-get update
sudo apt-get install -y gnucobol python3 python3-yaml shellcheck
cobc --version
```

### Windows

1. Install Git for Windows (this supplies Git Bash) and Python 3.10+.
2. Install a GnuCOBOL Windows build and put `cobc.exe` on `PATH`, or place a
   portable GnuCOBOL tree at `.tools/gnucobol/`; the scripts detect that tree.
3. In Git Bash, make sure Python 3.10+ is reachable. The Microsoft Store
   `python3` alias is not a usable interpreter; the scripts reject it and look
   for `python`. Set `PYTHON=/c/path/to/python.exe` if necessary.

The supplied GnuCOBOL runtime needs its `bin` directory on `PATH` so
`libcob-4.dll` can be found. `scripts/build.sh` and `scripts/test.sh` handle the
`.tools/gnucobol` case automatically.

## Build

From the repository root:

```bash
./scripts/build.sh
```

The script:

- locates `cobc` or a local portable compiler;
- compiles every production program with `-std=default -free -O2 -Wall -Wextra`;
- writes `build/bin/bnkapp` (or `bnkapp.exe` on Windows);
- writes `build/logs/compile.log`;
- fails on compiler errors **and** compiler warnings.

No generated binary is committed.

## Test

```bash
./scripts/test.sh
```

The test harness builds the application, compiles the COBOL unit drivers, and
runs deterministic integration cases. It writes:

- `build/test-results.json`
- `build/test-results.xml` (JUnit-compatible)
- `build/test-work/` (scenario outputs and diagnostics)

The current harness reports **36 tests and 0 failures** on the verified local
environment. Tests are independent of the network, secrets, a live mainframe,
and a real bank account.

## Demo

```bash
./scripts/run_demo.sh
```

The demo:

1. builds the application;
2. runs the sample batch into `.work/demo-stage`;
3. independently verifies balances, ledger totals, counts, error codes, and
   reports with `tests/verify_demo.py`;
4. only then moves the complete run to `output/demo`;
5. refuses to publish a failed batch and preserves diagnostics under
   `output/failed/demo`.

A successful published run contains `run_status.dat` with `status=SUCCESS` and
`settlement.dat` with `reconciliation_status|BALANCED`. A failed run does not
contain `run_status.dat`.

### Configuring a batch

`BNKMAIN` reads configuration from the environment. This keeps paths and dates
out of compiled code and makes test runs independent.

| Variable | Default | Meaning |
|---|---|---|
| `BNK_ACCOUNTS_FILE` | `data/sample/accounts.dat` | Account master input |
| `BNK_TRANSACTIONS_FILE` | `data/sample/transactions.dat` | Daily transaction input |
| `BNK_OUTPUT_DIR` | `output/demo` | Existing output directory |
| `BNK_RUN_ID` | `DEMORUN001` | 1-10 character run identifier |
| `BNK_PROCESS_DATE` | `2026-01-15` | `YYYY-MM-DD`, validated for calendar validity |
| `BNK_CURRENCY` | `USD` | Three alphabetic characters |

The output directory must already exist and must not contain `run_status.dat`,
`run_failure.dat`, or `run.lock`. `scripts/run_demo.sh` manages a clean staging
directory; direct runs must clean their output directory explicitly.

Example direct run:

```bash
mkdir -p .work/manual-run
BNK_ACCOUNTS_FILE=data/sample/accounts.dat \
BNK_TRANSACTIONS_FILE=data/sample/transactions.dat \
BNK_OUTPUT_DIR=.work/manual-run \
BNK_RUN_ID=MANUALRUN1 \
BNK_PROCESS_DATE=2026-01-15 \
BNK_CURRENCY=USD \
./build/bin/bnkapp
```

Exit codes:

| Code | Meaning |
|---|---|
| `0` | Batch completed, settlement balanced, reports generated |
| `8` | Reconciliation or integrity check failed |
| `12` | Fatal configuration, file, capacity, or processing failure |

Business rejections alone do **not** make the batch fail. They are recorded,
counted, and reconciled; a batch with rejected transactions can still exit `0`.

## Sample Input and Expected Output

See [data/expected/sample_expected.txt](data/expected/sample_expected.txt) for a
walkthrough. The committed sample contains 6 account records (5 loaded, 1
duplicate rejected) and 19 transaction records (4 accepted, 15 rejected).

Expected sample result:

| Metric | Expected |
|---|---:|
| Loaded accounts | 5 |
| Account exceptions | 1 (`A0003` duplicate) |
| Input transactions | 19 |
| Accepted | 4 |
| Rejected | 15 |
| Ledger entries | 5 (one transfer has two entries) |
| Deposits | 275.50 |
| Withdrawals | 500.00 |
| Transfer value | 300.00 |
| Accepted value | 1,075.50 |
| Rejected nominal value (absolute parseable amounts) | 4,844.00 |
| Ledger debits / credits | 800.00 / 575.50 |
| Opening / closing total | 9,350.00 / 9,125.50 |
| Net movement | -224.50 |
| Reconciliation | `BALANCED` |

Closing balances:

| Account | Opening | Closing | Debits | Credits |
|---|---:|---:|---:|---:|
| `ACC0000001` | 5,000.00 | 4,950.00 | 300.00 | 250.00 |
| `ACC0000002` | 2,500.00 | 2,300.00 | 500.00 | 300.00 |
| `ACC0000003` | 1,000.00 | 1,000.00 | 0.00 | 0.00 |
| `ACC0000004` (closed) | 750.00 | 750.00 | 0.00 | 0.00 |
| `ACC0000005` | 100.00 | 125.50 | 0.00 | 25.50 |

The daily report example:

```text
COBOL ENTERPRISE BANKING AND SETTLEMENT ENGINE
DAILY TRANSACTION REPORT
RUN ID: DEMORUN001   PROCESS DATE: 2026-01-15   CURRENCY: USD
RECONCILIATION STATUS: BALANCED
...
000003  TXN000000003  TRANSFER  ACC0000001  ACC0000002  +000000300.00  ACCEPTED
...
ACCEPTED TRANSACTIONS: 00000004   TOTAL AMOUNT: +000000000001075.50
```

## Transaction Rules

### Input record formats

All amounts are exact text; the program parses them before any arithmetic.

**Account master (80 bytes):**

| Positions | Field | Rule |
|---|---|---|
| 1-10 | Account id | `ACC` + 7 digits |
| 11-22 | Customer reference | Non-blank |
| 23 | Status | `A` active, `C` closed |
| 24-25 | Account type | `CH` or `SV` |
| 26-37 | Opening balance | `ddddddddd.dd`, non-negative, max 999,999,999.99 |
| 38-80 | Filler | Spaces; trailing filler may be omitted on input |

**Transaction (80 bytes; a short record is rejected):**

| Positions | Field | Rule |
|---|---|---|
| 1-12 | Transaction id | `TXN` + 9 digits |
| 13-22 | Type | `DEPOSIT`, `WITHDRAWAL`, or `TRANSFER` (space padded) |
| 23-32 | Source account | Required for all types |
| 33-42 | Destination account | Required only for `TRANSFER`; must be blank otherwise |
| 43-55 | Amount | `[+-]ddddddddd.dd`; `+` required for positive values |
| 56-80 | Filler | Spaces; trailing filler may be omitted |

A line longer than 80 bytes is rejected as malformed. The input buffer is 4096
bytes; the limitation is documented in
[docs/KNOWN_LIMITATIONS.md](docs/KNOWN_LIMITATIONS.md).

### Validation order and reject codes

The validation sequence is stable and documented for tests:

1. record length/layout;
2. transaction id syntax;
3. duplicate id;
4. supported type;
5. amount syntax, strict positivity, and maximum;
6. required accounts and type-specific field rules;
7. source/destination existence and active status;
8. source/destination distinctness;
9. available funds.

| Code | Meaning |
|---|---|
| `E0001` | Malformed, short, blank, or over-long transaction record |
| `E0002` | Transaction id is not `TXN` + 9 digits |
| `E0003` | Duplicate transaction id |
| `E0004` | Unsupported transaction type |
| `E0005` | Amount does not match the signed 2-decimal format |
| `E0006` | Amount is zero or negative |
| `E0007` | Source account is blank |
| `E0008` | Destination must be blank for deposit/withdrawal |
| `E0009` | Source account not found |
| `E0010` | Source account is closed |
| `E0011` | Destination account is required |
| `E0012` | Destination account not found |
| `E0013` | Destination account is closed |
| `E0014` | Insufficient available funds |
| `E0015` | Source and destination are the same |
| `E0016` | Amount or balance exceeds the supported maximum |

Account master exceptions use `A0001` through `A0007` (layout, id, duplicate,
status, type, balance, customer reference). Defensive processor codes `E0017`
(no valid validation result), `E0018`/`E0019` (invalid account index) are only
reachable by calling `BNKPROC` incorrectly; the batch never emits them in normal
operation.

A syntactically valid transaction id is reserved at its first appearance, even
if that transaction is rejected for another reason. Reusing it later is
rejected as a duplicate; this prevents replay from becoming valid after an
initial rejection.

## Financial Integrity

- Money is declared as signed packed decimal
  `PIC S9(9)V99 COMP-3` (6 bytes, 9 integer digits + 2 decimals).
- No floating-point arithmetic is used for balances or totals.
- All amounts are two-decimal values. There is no rounding in this project
  because no interest, fee, tax, or percentage calculation exists.
- Maximum single amount and balance: `999,999,999.99`.
- A transfer checks source funds and destination overflow before either account
  is changed.
- A rejected transaction performs no assignment to `ACCOUNT-TABLE`.
- Every accepted transaction produces one ledger row; every transfer produces
  two equal rows (`DEBIT` source, `CREDIT` destination).
- Settlement independently verifies:
  - accepted + rejected = control input count;
  - ledger count = accepted + transfer count;
  - each account: opening + credits - debits = closing;
  - output movement totals match ledger-derived movement totals;
  - aggregate closing - opening = deposits - withdrawals;
  - ledger credits - ledger debits = deposits - withdrawals;
  - every transfer has exactly one matching debit and credit.
- Rejected transactions cannot affect balances: any hidden application would
  break the per-account equation, the movement equation, or both.
- Reports are generated only after settlement passes; `run_status.dat` is
  written only after reports complete.

## GitHub Actions

The required workflow is
[.github/workflows/ci.yml](.github/workflows/ci.yml). It has five jobs with
explicit `needs` dependencies and timeouts:

1. **validate** — repository structure, YAML parser checks, ShellCheck;
2. **build** — install GnuCOBOL, compile all production programs;
3. **unit-integration-tests** — COBOL unit drivers and deterministic scenarios;
4. **end-to-end** — staged demo, independent verification, repeated-run hash
   comparison;
5. **documentation** — README links, required docs, credential-free CI checks.

The required workflow uses `permissions: contents: read`, pinned official
actions, no `continue-on-error`, and no secrets. It has **not been executed on
GitHub Actions in this environment**; local commands are the same commands the
workflow invokes. Do not infer a green CI run until a real run is inspected.

The optional [.github/workflows/zos-integration.yml](.github/workflows/zos-integration.yml)
requires manual dispatch and repository secrets. It uploads sources to a
dedicated USS directory and verifies a binary round-trip. It does **not**
compile or run anything on z/OS and is unverified against a real environment.
See [docs/MAINFRAME_MAPPING.md](docs/MAINFRAME_MAPPING.md).

## Verification Status

Verified locally on Windows 11 with Git Bash, Python 3.10.11, and GnuCOBOL
3.2.0:

- `./scripts/build.sh` — pass, no compiler warnings;
- `./scripts/test.sh` — 36 tests, 0 failures;
- `./scripts/run_demo.sh` — pass, 5 accounts, 4 accepted, 15 rejected,
  5 ledger entries, closing 9,125.50, `BALANCED`;
- repeated demo runs are byte-identical in the test harness;
- YAML parser validation and documentation checks are run locally where
  described above.

Not verified locally:

- GitHub Actions execution (no remote runner was available);
- a real IBM z/OS compile, link, or execution;
- the optional Zowe upload workflow.

The Zowe CLI 8.41.1 command names and help pages used by the optional workflow
(`list uss-files`, `upload file-to-uss`, `download uss-file`) were checked
locally with `zowe --help`; **no z/OSMF connection or upload was attempted**.

No result is reported as passing unless the corresponding local command or
workflow run actually succeeded.

## Mainframe Integration Status

There is **no deployed mainframe component** and **no live IBM Z connection** in
the standard project. The code is written for local GnuCOBOL and includes
mainframe-oriented design notes, illustrative JCL, and an optional upload
workflow.

This project **has not been tested against a real IBM z/OS system**. Uploading a
source file is not evidence that it compiles, links, or runs on z/OS. See
[docs/MAINFRAME_MAPPING.md](docs/MAINFRAME_MAPPING.md) and
[examples/jcl/README.md](examples/jcl/README.md).

## Known Limitations

See [docs/KNOWN_LIMITATIONS.md](docs/KNOWN_LIMITATIONS.md) for the full list.
Important examples:

- GnuCOBOL-specific dynamic `ASSIGN` and `LINE SEQUENTIAL` files require changes
  for IBM Enterprise COBOL / JCL.
- No VSAM, DB2, CICS, interest, fees, multi-currency, or concurrency support.
- The run lock is an advisory marker, not a crash-safe database transaction.
- Maximum capacities are 1,000 accounts, 5,000 transactions, and 10,000 ledger
  entries per batch.
- The project is not production-grade, not certified, and not a compliance
  product.
- COBOL Check was not available/verified in this environment; a portable COBOL
  unit harness plus Python integration verifier is used instead.

## Future Enhancements

- Add a DB2/VSAM persistence adapter and a restart checkpoint design.
- Add IBM Enterprise COBOL/JCL build profiles and a real z/OS integration run.
- Add property-based tests for amount/overflow boundaries.
- Add a read-only static HTML dashboard generated from settlement files, using
  the IBM-inspired palette documented in
  [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — only if it adds genuine value.
- Add multi-currency and explicit fee/interest policies with defined rounding.
- Add COBOL Check once a compatible, verified build is available.

## Interview Preparation

- [docs/INTERVIEW_NOTES.md](docs/INTERVIEW_NOTES.md) — 30-second explanation,
  architecture walkthrough, successful and rejected transaction walkthroughs,
  likely questions with accurate answers, and a tested-versus-untested matrix.
- [docs/COBOL_GUIDE.md](docs/COBOL_GUIDE.md) — PIC clauses, `COMP-3`, file
  status, copybooks, CALL interfaces, and GnuCOBOL versus Enterprise COBOL.
- [docs/TEST_PLAN.md](docs/TEST_PLAN.md) — test mapping and expected results.
- [docs/MAINFRAME_MAPPING.md](docs/MAINFRAME_MAPPING.md) — JCL, VSAM/DB2/CICS,
  Zowe/z/OSMF, and portability gaps.

## Security

Fictional data only. No credentials, tokens, real customer records, or live
banking connections are used by the required build or tests. See
[docs/SECURITY.md](docs/SECURITY.md). Do not use this project to process real
financial data.

## License

[MIT](LICENSE). IBM and IBM Z are trademarks of International Business Machines
Corporation. This project is not sponsored, endorsed, or certified by IBM.
