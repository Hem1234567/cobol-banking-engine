# Interview Notes

## Short Project Explanation

> I built a modular COBOL batch banking simulator with GnuCOBOL. It loads a
> fictional account master and daily transaction file, validates deposits,
> withdrawals, and transfers, applies accepted movements in packed decimal, and
> writes an auditable double-entry ledger. A separate settlement program
> independently recomputes balances and totals, pairs every transfer's debit and
> credit, and refuses to publish a success marker if anything is inconsistent.
> It is tested with COBOL unit drivers and deterministic integration scenarios,
> including rejected transactions, duplicate ids, malformed input, and fatal
> file errors. It runs locally; it has not been tested on IBM z/OS, and I do not
> claim a mainframe deployment.

## Technical Architecture Explanation

- `BNKMAIN` is the batch driver and owns all file I/O, the account table, and the
  transaction-id history.
- `BNKVALID` validates one transaction against the account table and returns a
  result. It does not touch balances or files.
- `BNKPROC` applies exactly one accepted transaction and creates one or two
  ledger entries. It checks funds and destination overflow before changing any
  account.
- `BNKSETTL` is deliberately independent. It re-reads outputs, recomputes
  account movements from the ledger, verifies counts and totals, and writes
  machine-readable reconciliation.
- `BNKRPT` formats reports from the already computed files and does no financial
  arithmetic.
- A shell demo stages the run under `.work/demo-stage` and only publishes
  `output/demo` after the COBOL app and a Python verifier both succeed.

## Transaction Walkthroughs

### Successful Transfer

Example `TXN000000003`, `TRANSFER`, `ACC0000001` to `ACC0000002`, `+000000300.00`.

1. The line is 80 bytes. `BNKMAIN` copies it into the transaction layout and
   checks the id format.
2. `BNKVALID` checks for a duplicate id, trims the type, validates the amount
   shape and positivity, and finds both accounts in the table.
3. It confirms both accounts are `A` (active), source and destination differ,
   and `300.00 <= 4950.00` available source balance.
4. `BNKPROC` rechecks the accounts and funds, subtracts 300 from the source,
   adds 300 to the destination, increments both movement counts, and builds a
   `DEBIT` row on the source and a `CREDIT` row on the destination.
5. `BNKMAIN` writes the two ledger rows, then the accepted record with both
   resulting balances.
6. `BNKSETTL` reads the accepted record and exactly two ledger rows, verifies the
   equal amounts and accounts, then recalculates both account closings.
7. Settlement compares opening + credits - debits to closing and confirms
   aggregate movement is unchanged by internal transfers.
8. `run_status.dat` is written only after all checks and reports pass.

### Rejected Withdrawal

Example `TXN000000004`, `WITHDRAWAL` from `ACC0000003`, `+000001500.00` against a
`1000.00` balance.

1. The id and amount are syntactically valid.
2. `BNKVALID` finds the active source account and compares the amount with the
   balance.
3. It sets `VLR-OK` to `N`, error code `E0014`, and detail
   `INSUFFICIENT AVAILABLE FUNDS`.
4. `BNKMAIN` does not call `BNKPROC`. It writes a rejected record containing the
   sequence, original fields, error code, and detail.
5. No account field and no ledger row changes.
6. Settlement counts the rejection but derives all account movements from the
   ledger. The account equation still holds, and the rejection makes no
   financial impact.

## Data Representation Questions

### What is `PIC X(10)`?

A ten-character alphanumeric field. It stores text without numeric validation;
the program checks patterns explicitly.

### What is `PIC S9(9)V99 COMP-3`?

A signed packed-decimal field with nine integer digits and two implied decimal
digits. `V` does not occupy storage. `COMP-3` stores two digits per byte plus a
sign nibble, so `S9(9)V99` takes six bytes. It is exact for money and avoids
binary floating-point errors.

### Why is `COMP-3` appropriate?

It represents base-10 amounts exactly, is compact, and is a standard enterprise
COBOL money representation. It does not remove the need to check ranges,
overflow, input validation, and reconciliation.

### What is a numeric edited field?

A display-only field with decimal points, signs, or zero suppression. Example:
`PIC 9(9).99` renders 12 characters including the dot. It is used for text
output, not for arithmetic.

### How are negative amounts handled?

The input supports a leading `-`, but all accepted transactions must be strictly
positive. Negative and zero amounts get `E0006`. Rejected nominal totals use
absolute parseable values.

## Validation Questions

### What is the validation order?

Id syntax, duplicate id, supported type, amount syntax and positivity, required
accounts/type-specific fields, account existence and active status, source vs.
destination, available funds. This order is documented and tested so error codes
are stable.

### How are duplicates detected?

`BNKMAIN` keeps an array of reserved 12-character transaction ids. `BNKVALID`
scans it before accepting a transaction. The current id is reserved after
validation even if the transaction is rejected, preventing a replay from
becoming valid later. The table is capped at 5,000, the batch transaction limit.

### Why check funds twice?

`BNKVALID` performs the business validation and `BNKPROC` defensively rechecks
before mutating. This protects the financial invariant if the processor is ever
called with stale or hand-built data; the unit tests call `BNKPROC` directly and
verify the guard.

### How does a rejected transaction preserve balances?

`BNKPROC` is only called when `VLR-OK = "Y"`, and it checks source/destination
status and funds before any assignment. Rejections are written by `BNKMAIN`
without table mutation. Settlement independently checks that closing equals
opening plus ledger movements, so an accidental hidden update fails
reconciliation.

## Ledger and Reconciliation Questions

### What invariants prove the ledger is consistent?

- accepted count + transfer count = ledger row count;
- every accepted transaction matches its ledger rows by id and amount;
- every transfer has one debit on the source and one credit on the destination,
  with the same amount;
- per-account closing = opening + credits - debits;
- output movement totals equal ledger-derived totals;
- aggregate movement = deposits - withdrawals;
- ledger net = deposits - withdrawals.

### Why not just trust the balance report?

A report can be internally consistent and still omit a ledger row, double-apply
a transaction, or use a wrong total. `BNKSETTL` recomputes from the primitive
records and compares counts, account equations, and totals. Reports are derived
views, not audit evidence.

### Why are deposits/withdrawals one-sided in the ledger?

They represent external cash movements; there is no modeled bank cash account.
A transfer is internal and therefore has two equal sides. A more complete bank
ledger would add a cash/clearing contra-account; that is outside this project's
scope.

## COBOL Mechanics Questions

### How are sequential files read?

With `SELECT ... ORGANIZATION IS LINE SEQUENTIAL`, `FILE STATUS`, `OPEN INPUT`,
and a `READ` loop that handles `00`, `10` EOF, and other statuses. Every
`WRITE`/`CLOSE` status is checked too.

### What do copybooks do?

They textually include shared record definitions at compile time. The same
copybook is used in the caller's working storage and callee's linkage section so
byte layouts match. Copybooks do not create runtime shared memory.

### How are programs linked?

`cobc -x` compiles and links all five COBOL sources into one executable.
`CALL "BNKVALID"` and `CALL "BNKPROC"` are literal calls; the build script is the
single source of truth for the link set.

### Why free format?

It reduces column-sensitive mistakes and is supported by GnuCOBOL and modern
Enterprise COBOL. The build passes `-free` explicitly.

## GnuCOBOL vs. Enterprise COBOL

The largest differences are file control, encoding, and runtime:

- local `ASSIGN TO WS-PATH` and environment paths vs. static DD names and JCL;
- `LINE SEQUENTIAL` ASCII vs. EBCDIC sequential/VSAM data sets;
- `cobc` vs. `IGYCRCTL`, binder, and load library;
- process exit codes vs. JCL step return codes and condition codes.

The business logic uses portable COBOL constructs, but a real z/OS port requires
file-control and JCL work. I do not claim the local code compiles or runs on
z/OS.

## Interview Questions

Likely questions and accurate answers:

**1. Why did you use `COMP-3` instead of `COMP-2`?**
`COMP-2` is binary floating point and cannot represent every decimal amount
exactly. `COMP-3` is packed decimal and is exact for two-decimal money.

**2. What happens if two transactions have the same id?**
The first syntactically valid occurrence is reserved; later ones get `E0003`
and are not applied. A rejected first attempt still reserves the id.

**3. What happens if a transfer's destination is closed?**
`BNKVALID` returns `E0013`; `BNKPROC` is not called; no balances or ledger
entries change.

**4. What prevents an overflow?**
Inputs are limited to nine integer digits/two decimals. `BNKPROC` computes a
larger work value for a prospective destination balance and checks it before
mutating either transfer account. Deposit overflow is likewise checked before
the `ADD`.

**5. What is the maximum amount?**
`999,999,999.99`; there is no rounding because there are no percentage/fee
calculations.

**6. How is the processing date controlled?**
`BNK_PROCESS_DATE` is supplied by the fixture/script; the program validates the
calendar date and writes it to ledger rows. No wall-clock timestamp is used, so
runs are deterministic.

**7. How is a failed batch prevented from looking successful?**
Reconciliation must return `BALANCED`, reports must be generated, and only then
is `run_status.dat` written. The demo stages output and publishes it only after
an independent verifier succeeds; a failed staging directory gets no success
marker.

**8. Is the run lock crash-safe?**
No. It is an advisory marker that prevents ordinary replay, not an OS lock or a
database transaction. This is explicitly listed as a limitation.

**9. How would you make this production-grade?**
Use DB2/VSAM with real commit and restart semantics, a scheduler enqueue lock,
checkpointing, encryption, access control, audit logging, generation data sets,
mainframe compile/JCL testing, and a formal compliance program. This portfolio
project does none of those things to production standard.

**10. What did you actually test?**
GnuCOBOL 3.2.0 local build; 19 validation unit cases; 9 processor unit cases;
8 integration scenarios including a large deposit, empty input, invalid
accounts, over-long input, fatal missing files, rerun refusal, and deterministic
repeat runs; independent ledger/account reconciliation. The required GitHub
Actions workflow passed remotely for commit `7ddb59e`; I did not test z/OS.

## Recruiter-Friendly Summary

- Real COBOL, not a mockup: five production programs and copybooks.
- Financial correctness: packed decimal, atomic rejections, double-entry
  transfers, independent reconciliation.
- Engineering discipline: build/test scripts, CI, staged publication, explicit
  limitations, and no credential requirements.
- Mainframe literacy without false claims: JCL, VSAM/DB2/CICS, Zowe, and
  portability gaps are documented, while z/OS execution remains untested.

## Tested vs. Untested Matrix

| Area | Status |
|---|---|
| GnuCOBOL compile | Verified locally, warning-free |
| Unit tests | Verified locally |
| Integration and demo | Verified locally |
| Determinism | Verified byte-for-byte in harness |
| GitHub Actions | Full remote run passed for `7ddb59e` |
| IBM z/OS compile/link/run | Not tested |
| Zowe upload | Configured, not connected to real z/OSMF |
| VSAM/DB2/CICS | Conceptual only |
| Production security/compliance | Not claimed |
