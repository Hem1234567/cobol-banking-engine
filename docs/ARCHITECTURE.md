# Architecture

## Overview

The engine is a modular, file-based COBOL batch application. It deliberately
separates **validation**, **financial mutation**, **settlement**, and
**reporting** so that each can be tested and explained independently. The main
program owns all file I/O; called subprograms exchange fixed-layout records and
result structures through `LINKAGE SECTION` definitions copied from shared
copybooks.

The execution model is deterministic: files are read sequentially, transactions
are applied in input order, no timestamps are written, and reports are rendered
from the files produced by the same run. The same inputs and environment produce
byte-identical output.

## Program Responsibilities

| Program | Inputs | Outputs | Side effects |
|---|---|---|---|
| `BNKMAIN` | account and transaction files, environment config | accepted, rejected, account exceptions, ledger, account summary, control, run lock | orchestrates batch; writes run status or failure marker |
| `BNKVALID` | transaction record, account table, id history, counts | `VALIDATION-RESULT` | none; no file or balance changes |
| `BNKPROC` | transaction record, account table, validation result | `PROCESS-RESULT` with 1-2 ledger entries | mutates in-memory balances only after all checks pass |
| `BNKSETTL` | batch output files, control totals, run metadata | `SETTLEMENT-RESULT`, `settlement.dat`, `reconciliation.dat` | writes settlement/reconciliation diagnostics |
| `BNKRPT` | settlement, reconciliation, accepted, rejected, account, exception files | five text reports | writes reports; no financial arithmetic |

### Why BNKMAIN owns file I/O

Enterprise COBOL batches commonly keep file control in the driver and call
subprograms for business rules. This avoids duplicating `FILE STATUS` handling
across modules and keeps `BNKVALID`/`BNKPROC` pure enough to unit test without
files. It also means a file failure cannot be hidden inside a business module.

### Why settlement is independent

`BNKSETTL` does not trust the driver's counters. It re-reads the output records,
pairs every accepted transaction with its ledger entries, recomputes account
movements, and compares the results to `batch_control.dat`. This is the key
control that catches a missed ledger write, an accidental second application of
a rejected transaction, or a wrong total.

## Data Flow

```text
                       +-------------------+
accounts.dat  -------> |                   |
                       |     BNKMAIN       |----> account_exceptions.dat
transactions.dat ----> |  account table    |
                       |  id history       |----> accepted.dat
                       |  file control     |----> rejected.dat
                       +---------+---------+----> ledger.dat
                                 |                accounts_out.dat
                                 |                batch_control.dat
                                 |                run.lock
                                 |
                   +-------------+-------------+
                   |                           |
                   v                           v
              BNKVALID                     BNKPROC
          validate and index            apply debit/credit
                   |                           |
                   +-------------+-------------+
                                 |
                                 v
                             BNKMAIN
                                 |
                   +-------------+-------------+
                   |                           |
                   v                           v
              BNKSETTL                      BNKRPT
        independent checks            deterministic reports
                   |                           |
                   +-------------+-------------+
                                 |
                                 v
                  run_status.dat only on success
```

## CALL Interfaces

The shared interfaces are in
[src/main/cobol/copy/INTERFACES.cpy](../src/main/cobol/copy/INTERFACES.cpy).

```text
CALL "BNKVALID"
  USING TRANSACTION-FILE-RECORD
        ACCOUNT-TABLE
        ACCOUNT-COUNT
        ID-HISTORY
        ID-COUNT
        VALIDATION-RESULT

CALL "BNKPROC"
  USING TRANSACTION-FILE-RECORD
        ACCOUNT-TABLE
        VALIDATION-RESULT
        PROCESS-RESULT

CALL "BNKSETTL"
  USING OUTPUT-DIRECTORY
        RUN-ID
        PROCESS-DATE
        CURRENCY
        SETTLEMENT-RESULT

CALL "BNKRPT"
  USING OUTPUT-DIRECTORY
        RUN-ID
        PROCESS-DATE
        CURRENCY
        REPORT-RESULT
```

All called programs are compiled into the same `bnkapp` executable by the build
script. `BNKMAIN` uses literal `CALL` names so the call graph is visible and
stable.

## Record and Table Sizes

| Structure | Capacity / length | Notes |
|---|---|---|
| Account table | 1,000 entries | linear lookup by account id |
| Transaction id history | 5,000 entries | ids reserved at first appearance |
| Transaction ids per batch | 5,000 | fatal capacity error beyond this |
| Ledger entries per batch | 10,000 | max two per accepted transaction |
| Input line buffer | 4,096 bytes | over-80-byte records rejected |
| Account master record | 80 bytes | fixed-width, line sequential |
| Transaction record | 80 bytes | short records rejected |
| Accepted record | 100 bytes | padded by line-sequential runtime |
| Rejected record | 124 bytes | includes error and detail |
| Ledger record | 100 bytes | one row per debit/credit |
| Account summary | 100 bytes | opening, movement, closing, count |
| Control/reconciliation rows | 300 bytes | key/value or check rows |
| Report rows | 300 bytes | fixed text reports |

`LINE SEQUENTIAL` means the last non-space bytes of each output row may be
trimmed on disk. Readers pad them back to the declared record width. Fixed
positions therefore remain stable.

## Batch Lifecycle

1. **Configuration**: read `BNK_*` environment variables, apply defaults,
   validate run id length, calendar date, currency, and output path length.
2. **Refuse unsafe replay**: check for `run_status.dat` and `run.lock`; fail if
   either exists. Create `run.lock` with `IN_PROGRESS` metadata.
3. **Open outputs** in the existing output directory.
4. **Load accounts**: sequential read, validate layout and values, reject
   malformed/duplicate records into `account_exceptions.dat`, load first valid
   occurrence into the in-memory table.
5. **Process transactions**: read sequentially; reserve syntactically valid ids;
   reject malformed/over-long lines; call `BNKVALID`, then `BNKPROC` only for
   accepted transactions; write ledger then accepted/rejected rows.
6. **Write account summaries and control file**, close all outputs, checking
   every `FILE STATUS`.
7. **Call `BNKSETTL`**: independent settlement and reconciliation. A failure
   returns a nonzero result; `BNKMAIN` writes `run_failure.dat` and exits
   without a success marker.
8. **Call `BNKRPT`**: generate all five reports.
9. **Publish success marker**: write `run_status.dat` with `status=SUCCESS`.
10. **Demo publication**: the shell script moves the complete staged directory
    to `output/demo` only after the application and the independent Python
    verifier succeed.

## Data and File Naming

A run directory contains:

```text
run.lock
account_exceptions.dat
accepted.dat
rejected.dat
ledger.dat
accounts_out.dat
batch_control.dat
settlement.dat
reconciliation.dat
daily_transaction_report.txt
account_balance_report.txt
exception_report.txt
settlement_report.txt
reconciliation_report.txt
run_status.dat          (success only)
run_failure.dat         (failure only)
```

`run.lock` is deliberately retained after a failure for diagnostics and replay
prevention. A new run requires an explicitly cleaned/new directory; the scripts
use `.work/demo-stage` and remove it first.

## Invariants

### Transaction-level

- A transaction is either accepted exactly once or rejected without mutation.
- A rejected transaction has a stable six-character error code and leaves the
  account table unchanged.
- A transfer has two distinct, active accounts.
- A transfer's debit and credit amounts are identical.
- Accepted transactions are processed in input order.

### Ledger-level

- Every accepted transaction has one ledger row.
- Every accepted transfer has exactly two rows: `DEBIT` source and `CREDIT`
  destination.
- Ledger rows carry transaction id, account id, amount, processing date, and run
  id.
- Ledger count equals accepted count plus transfer count.

### Account-level

For every account:

```text
closing = opening + ledger credits - ledger debits
output debits = ledger debits
output credits = ledger credits
output entry count = ledger entry count
```

### Settlement-level

```text
accepted + rejected = control input count
closing total - opening total = deposit total - withdrawal total
ledger credits - ledger debits = deposit total - withdrawal total
sum of parseable rejected amounts = rejected nominal total
```

All checks must be `PASS` and `SET-RECON-STATUS` must be `BALANCED` before a
success marker is written.

## Failure and Restart Behaviour

- Fatal configuration/file/capacity errors return `12`; integrity failures
  return `8`.
- A failure writes `run_failure.dat` when the output directory is writable and
  does not write `run_status.dat`.
- The demo script preserves a failed staging directory under
  `output/failed/demo`, removing any success marker if independent verification
  later fails.
- There is **no resume/checkpoint** feature. A failed run must be restarted into
  a clean directory.
- The run lock is only an advisory file marker. It is not an OS file lock and
  cannot prevent two processes racing between the existence check and the
  create. For a real bank batch, use a scheduler enqueue lock and generation
  data sets.

## Presentation Policy

The core application has **no frontend**. Deterministic text reports are the
authoritative deliverables; a frontend would not add genuine value to the
file-based batch proof. If a read-only dashboard is added later, the intended
IBM-inspired palette is:

| Role | Color |
|---|---|
| Primary | `#0F62FE` |
| Background | `#161616` |
| Surface | `#262626` |
| Text | `#F4F4F4` |
| Secondary text | `#C6C6C6` |
| Success | `#42BE65` |
| Warning | `#F1C21B` |
| Error | `#FA4D56` |

Any dashboard must derive every number from real output files, label demo data,
and never simulate a successful batch. No IBM trademarks or sponsorship are
implied.

## Extension Points

- Replace the in-memory account table with VSAM KSDS or DB2 access without
  changing `BNKVALID`/`BNKPROC` interfaces.
- Add a checkpoint file keyed by input sequence for restart.
- Add an Enterprise COBOL build path that uses static `ASSIGN` names and JCL
  `DD` statements.
- Add a COBOL Check project once a verified compatible runner exists.
- Add multi-currency and fee policies only after defining rounding and
  reconciliation rules.
