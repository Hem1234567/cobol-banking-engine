# COBOL and Data Representation Guide

## Source Format

All programs start with:

```cobol
>>SOURCE FORMAT FREE
```

Free format lets code start in column 1 and removes the fixed-format area A/B
rules. The build passes `-free` explicitly so the compiler behavior does not
depend on a file-name suffix. IBM Enterprise COBOL also supports free format,
but the file-control and runtime details in this project remain
GnuCOBOL-oriented.

## PIC Clauses

### `PIC X(n)` — alphanumeric

Used for identifiers, references, error codes, dates, and text.

```cobol
05  TXF-ID                 PIC X(12).
05  ACF-CUSTOMER-REF       PIC X(12).
```

`X` fields do not validate themselves. The batch checks patterns, for example:

```cobol
IF TXF-ID(1:3) NOT = "TXN"
    OR TXF-ID(4:9) IS NOT NUMERIC
```

### `PIC 9(n)` — unsigned numeric display

Used for counts, sequence numbers, and output counters.

```cobol
05  ACR-SEQUENCE           PIC 9(06).
```

The digits are stored as characters, which makes fixed reports readable. A
binary `COMP` variant is used for internal counters where file layout does not
matter.

### `PIC S9(9)V99` — signed numeric with implied decimal

`V` is an **implied** decimal point and occupies no storage. The value
`123456789.99` is stored as the digits `12345678999` plus a sign; editing adds
the decimal point when displaying.

This project uses:

```cobol
01  ACT-BALANCE            PIC S9(9)V99 COMP-3.
```

That is 9 integer digits, 2 decimal digits, signed, packed decimal. The maximum
supported value is `999,999,999.99`.

### Numeric edited fields

To render a decimal for a report or text file:

```cobol
01  WS-BAL-EDIT            PIC 9(9).99.
...
MOVE ACT-BALANCE(WS-IDX) TO WS-BAL-EDIT
MOVE WS-BAL-EDIT TO ACO-CLOSING-TEXT
```

The edited picture inserts the `.` and produces a fixed 12-character text
value, which can then be stored in a `PIC X(12)` field.

For signed totals and settlement output:

```cobol
01  WS-TOTAL-EDIT          PIC +9(15).99.
```

The `+` editing symbol prints `+` for positive values and `-` for negative
values. It is a presentation field, not a calculation field.

## COMP-3

`COMP-3` means **packed decimal**. Two decimal digits are stored per byte, with
a sign nibble in the last byte. For `S9(9)V99`, there are 11 digits plus a sign:
`ceil(12 / 2) = 6` bytes.

Why it is appropriate here:

- exact base-10 arithmetic for money;
- no binary floating-point representation error;
- compact storage and fast decimal operations on mainframe processors;
- familiar enterprise COBOL representation.

What it does **not** provide:

- automatic range checking (a receiving field can still be too small);
- a defined source-level encoding across every platform;
- database or ledger durability.

All arithmetic in the financial path uses `COMP-3` or larger `COMP-3` work
fields. No `COMP-1` or `COMP-2` floating-point fields exist.

## Signed Amount Input

Human-facing input uses exact text, not packed bytes:

```text
[+-]ddddddddd.dd
```

Examples:

```text
+000000250.00
+000001500.00
-000000025.00
```

The leading sign is required. Validation checks the sign position, integer
digits, decimal point position, and two decimal digits **before** moving the
value into a numeric field:

```cobol
IF TXF-AMOUNT-TEXT(1:1) NOT = "+"
    AND TXF-AMOUNT-TEXT(1:1) NOT = "-"
...
IF TXF-AMOUNT-TEXT(2:9) IS NOT NUMERIC
    OR TXF-AMOUNT-TEXT(11:1) NOT = "."
    OR TXF-AMOUNT-TEXT(12:2) IS NOT NUMERIC
...
COMPUTE VAL-AMOUNT = FUNCTION NUMVAL(TXF-AMOUNT-TEXT)
```

`FUNCTION NUMVAL` converts the already-validated text to a numeric value. The
program then rejects values `<= 0` and values above the supported maximum.

## File Status and Sequential Processing

Every file has a status field:

```cobol
SELECT ACCOUNT-FILE ASSIGN TO WS-ACCOUNT-PATH
    ORGANIZATION IS LINE SEQUENTIAL
    FILE STATUS IS WS-ACCOUNT-FS.
```

Every `OPEN`, `READ`, `WRITE`, and `CLOSE` is checked. A typical read loop:

```cobol
PERFORM UNTIL WS-ACCOUNT-EOF = "Y"
    READ ACCOUNT-FILE END-READ
    EVALUATE WS-ACCOUNT-FS
        WHEN "00"
            PERFORM PROCESS-ACCOUNT-RECORD
        WHEN "04"
            PERFORM PROCESS-ACCOUNT-RECORD
        WHEN "10"
            MOVE "Y" TO WS-ACCOUNT-EOF
        WHEN OTHER
            ... fatal error ...
    END-EVALUATE
END-PERFORM
```

Relevant status values:

| Status | Meaning here |
|---|---|
| `00` | success |
| `04` | record-length warning; treated as a record to validate |
| `10` | end of file |
| `35` | file not found; used only for the optional run-marker check |
| other | fatal infrastructure error |

`LINE SEQUENTIAL` is used because the sample data is human-readable and
platform-newline aware. On z/OS a fixed or variable sequential data set would use
JCL `DD` statements and a different `ASSIGN`.

## Copybooks and Modular Design

`COPY` inserts shared record declarations at compile time. The project uses:

- [ACCOUNT.cpy](../src/main/cobol/copy/ACCOUNT.cpy) — account input, summary,
  exception, and table;
- [TRANSACT.cpy](../src/main/cobol/copy/TRANSACT.cpy) — transaction input,
  accepted/rejected output, and id history;
- [LEDGER.cpy](../src/main/cobol/copy/LEDGER.cpy) — ledger record and sequence;
- [INTERFACES.cpy](../src/main/cobol/copy/INTERFACES.cpy) — validation, process,
  settlement, and report result structures.

Using the same copybook in the caller's `WORKING-STORAGE` and the callee's
`LINKAGE SECTION` keeps byte layouts synchronized. It does not create shared
memory; `CALL ... USING` passes references.

## CALL and Copybooks

### CALL and Linkage Sections

`BNKMAIN` calls validation without allowing it to touch files or balances:

```cobol
CALL "BNKVALID" USING TRANSACTION-FILE-RECORD
                       ACCOUNT-TABLE
                       WS-ACCOUNT-COUNT
                       ID-HISTORY
                       WS-ID-COUNT
                       VALIDATION-RESULT
END-CALL
```

`BNKVALID` declares matching items in `LINKAGE SECTION` and returns a result.
`BNKPROC` receives the validation result and mutates the table only after
rechecking source/destination state and funds.

This design makes unit tests possible without files: `TESTVALID.CBL` and
`TESTPROC.CBL` build in-memory tables and call the production modules directly.

## Paragraph Style

- Short paragraphs with one responsibility.
- No `GO TO`.
- Explicit scope terminators (`END-IF`, `END-PERFORM`, `END-CALL`, `END-WRITE`,
  `END-READ`, `END-DISPLAY`, `END-ACCEPT`) to keep nesting unambiguous.
- Stable error codes and detail text.
- ASCII-only source and data for predictable Git and CI behavior.

## Build Flags

`scripts/build.sh` uses:

```text
-std=default -free -O2 -Wall -Wextra -I src/main/cobol/copy
```

- `-std=default` keeps the default GnuCOBOL dialect, including documented
  extensions used for dynamic file assignment.
- `-free` selects free source format.
- `-O2` enables optimization.
- `-Wall -Wextra` enable warnings.
- `-I` locates copybooks.

The build fails if the compiler exits nonzero or emits a warning.

## GnuCOBOL Versus IBM Enterprise COBOL

| Topic | This project (GnuCOBOL) | IBM Enterprise COBOL / z/OS |
|---|---|---|
| File assignment | `ASSIGN TO WS-PATH` variable, environment paths | static `ASSIGN TO ddname`, JCL `DD` |
| File organization | `LINE SEQUENTIAL` | fixed/variable sequential data sets, VSAM, DB2 |
| Character encoding | ASCII on disk | EBCDIC on z/OS, conversion required |
| Compiler | `cobc` | `IGYCRCTL` / compiler procedures |
| Link/edit | `cobc -x` | `IEWL` / binder and load library |
| Runtime config | environment variables | JCL, PARM, subsystem, operator |
| Exit/return code | process exit code plus `RETURN-CODE` | job step return code, `COND` |
| Copybooks | `COPY "FILE.cpy"` with `-I` | `COPY` from SYSLIB/PDS |
| Date/clock | no timestamp in outputs | mainframe clock/date facilities |
| COBOL Check | not available/verified here | third-party tool, not standard |

Porting requires replacing dynamic `ASSIGN` with DD names, mapping line
sequential records to fixed/variable data sets, converting encodings, and
providing compiler/link JCL. The business paragraphs and copybook layouts are
mostly portable, but the file-control layer is not.

## Common Pitfalls Demonstrated

- **Spaces are not numeric.** An amount field of spaces fails the digit checks.
- **`V` stores no decimal point.** A numeric edited field is needed for text.
- **Unchecked `FILE STATUS` hides data loss.** Every operation is checked.
- **A rejected transaction must not partially update an account.** `BNKPROC`
  checks before assigning and uses `ON SIZE ERROR`-style prechecks for balances.
- **Duplicate ids must be reserved before rejection decisions.** A rejected
  attempt still consumes the id to block later replay.
- **Reports are not a ledger.** `ledger.dat` is a separate fixed-layout
  auditable file; reports are derived views.
- **Uploading source is not execution.** See the mainframe documentation.
