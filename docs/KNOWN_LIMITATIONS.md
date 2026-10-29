# Known Limitations and Unimplemented Features

This file is intentionally explicit. Absence of a feature here must not be read
as production readiness.

## Functional Limits

- **Single currency per run.** `BNK_CURRENCY` is metadata; the engine does not
  perform FX conversion or maintain currency per account.
- **No interest, fees, tax, or accrual.** There is no rounding policy beyond
  exact two-decimal input values.
- **No account creation, closure, or customer maintenance.** Account status is
  loaded from the master file.
- **No loans, cards, payments, wires, ACH, SWIFT, or ISO 20022 messages.**
- **No holds, pending balances, overdrafts, or credit limits.**
- **No authorization model, user identity, or role-based access.**
- **No multi-batch or multi-day history.** Each run is a standalone file set.
- **Closed accounts remain in the reporting population** with unchanged
  balances; they cannot participate in accepted movements.
- **Deposit/withdrawal semantics:** `DEPOSIT` credits `TXF-SOURCE` and requires a
  blank destination; `WITHDRAWAL` debits `TXF-SOURCE` and requires a blank
  destination. There is no separate cash/bank settlement account.
- **Rejected nominal total** is the sum of absolute, parseable rejected amounts.
  Malformed amounts contribute zero.
- **Duplicate-id policy:** a syntactically valid id is reserved at its first
  appearance, including rejected attempts. A later reuse is rejected.
- **Date validation** covers a real calendar date from 1900 onward; it does not
  model mainframe Julian dates, time zones, or cutoff windows.

## Capacity and Format Limits

- 1,000 loaded accounts.
- 5,000 input transactions.
- 10,000 ledger entries.
- 4,096-byte maximum physical input line; logical records longer than 80 bytes
  are rejected. A physical line longer than 4,096 bytes may be truncated by the
  runtime.
- Fixed-width, ASCII, line-sequential files.
- Money fields use nine integer digits and two decimal digits:
  `999,999,999.99` maximum.
- Output rows may have trailing spaces trimmed by `LINE SEQUENTIAL`; readers
  pad them back to their declared fixed width.
- Reports are plain text; there is no PDF/HTML rendering or dashboard.

## Portability Limits

- `ASSIGN TO` a working-storage path is a GnuCOBOL extension used for test and
  demo portability. IBM Enterprise COBOL would use static DD names and JCL.
- Files are ASCII/UTF-8-compatible text, not EBCDIC z/OS data sets.
- The code relies on `LINE SEQUENTIAL`, which is not a z/OS native file
  organization.
- Environment variables replace JCL `DD`/`PARM` configuration.
- The build uses GnuCOBOL and `cobc`, not `IGYCRCTL`, the binder, and a load
  library.
- Intrinsic function behavior should be rechecked against the site's Enterprise
  COBOL version.
- COBOL source is free format; site compiler options must enable it.

## Operational Limits

- **No database or VSAM.** Account data exists only in memory for the run.
- **No checkpoint/restart.** A failed run restarts from the beginning into a
  clean output directory.
- **No crash-safe atomic publish at the application level.** The demo uses a
  staging directory and a same-filesystem rename; this is not a general
  transaction log or a guarantee against power loss.
- **Advisory run lock only.** Two processes can race between the existence check
  and file creation. A production scheduler must provide a real enqueue lock.
- **No concurrency control.** The program assumes one writer per output
  directory.
- **No generation data groups, backups, retention policy, or archival.**
- **No SMF/RACF/security integration.**
- **No online CICS path.**
- **No encryption at rest or in transit.**
- **No scheduler integration.**
- **No performance tuning for production volumes.** Linear account lookup is
  intentional for readability at the stated capacities.

## Testing Limits

- COBOL Check was not available and verified in this environment. A portable
  COBOL driver plus a Python integration verifier is used instead.
- Tests are deterministic and small; they are not a load test.
- No fault-injection test for disk-full, power loss, or concurrent writers.
- No test on IBM Enterprise COBOL or z/OS.
- GitHub Actions was not executed in the local environment; the workflow syntax
  and commands were validated locally, but a real remote run is still required.
- The optional Zowe upload workflow has not been connected to a real z/OSMF
  endpoint.
- No fuzzing of arbitrary binary input.

## Integration Status

- **Tested locally:** GnuCOBOL 3.2.0 compile, 36 automated tests, demo and
  independent reconciliation.
- **Not tested:** GitHub Actions remote execution, z/OS compile/link/run,
  VSAM/DB2/CICS, Zowe upload.
- Uploading a file is not evidence of compilation or execution.
- The standard CI workflow does not require a mainframe, credentials, or a
  network service.

## Compliance and Security Status

This project is **not production-ready** and **not certified** for banking,
payments, privacy, or regulatory use. It has no compliance attestation. Do not
process real financial or personal data with it.
