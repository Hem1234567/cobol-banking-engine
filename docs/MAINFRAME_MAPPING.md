# Mainframe Concepts and Mapping

## Purpose

This document maps the local GnuCOBOL application to IBM z/OS concepts for
interview and learning purposes. It does **not** claim that the project runs on
z/OS. The standard build and test suite are local GnuCOBOL only.

## z/OS Concepts

- **IBM Z** is the hardware family; **z/OS** is the operating system used for
  enterprise batch and transaction workloads.
- **JCL** (Job Control Language) describes a job, its steps, programs, and data
  sets.
- **Batch** work runs as a job, often scheduled outside interactive hours.
- **VSAM** provides keyed and sequential data sets; **DB2** provides relational
  tables; **CICS** provides online transaction processing.
- **Return codes** communicate step success/failure to the scheduler and to
  conditional JCL.
- **z/OSMF** provides REST services for systems management; **Zowe CLI** is a
  command-line client for z/OSMF and related services.

## Mapping the Local Components

| Local component | z/OS equivalent |
|---|---|
| `accounts.dat` | VSAM KSDS, DB2 table, or sequential account master |
| `transactions.dat` | sequential daily transaction data set |
| `accepted.dat` / `rejected.dat` | sequential output/exception data sets |
| `ledger.dat` | sequential ledger extract or DB2 ledger table |
| `accounts_out.dat` | updated account extract or VSAM/DB2 update |
| `batch_control.dat` | control-card/control-report data set |
| output directory | generation data group (GDG) or run-specific data sets |
| `BNKMAIN` process | batch job step, often a COBOL program under JCL |
| `BNKVALID`/`BNKPROC` CALLs | COBOL subprograms in a load library |
| `BNKSETTL` | reconciliation job step with `COND` checking |
| text reports | SYSOUT or report data sets |
| exit 0/8/12 | step return code / job scheduler condition |
| environment variables | JCL `DD`, `PARM`, and site configuration |
| `run.lock` | scheduler enqueue or data-set allocation discipline |
| `output/failed/demo` | retained job output/SYSOUT for diagnosis |

## JCL

JCL has three core statement types:

- `JOB` identifies the job, accounting information, and job class.
- `EXEC` selects a program or cataloged procedure.
- `DD` describes a data set or system output.

A simplified, **illustrative** compile/link/run shape:

```jcl
//BANKBAT  JOB (ACCT),'COBOL BANK BATCH',CLASS=A,MSGCLASS=X
//COMPILE  EXEC PGM=IGYCRCTL,REGION=0M
//SYSPRINT DD SYSOUT=*
//SYSLIB   DD DISP=SHR,DSN=&HLQ..COPYLIB
//SYSIN    DD DISP=SHR,DSN=&HLQ..COBSRC(BNKMAIN)
//SYSLIN   DD DSN=&&OBJ,DISP=(NEW,PASS),SPACE=(TRK,(10,10))
//LINK     EXEC PGM=IEWL,COND=(4,LT,COMPILE)
//SYSLIB   DD DISP=SHR,DSN=&HLQ..LOADLIB
//SYSLIN   DD DISP=(OLD,DELETE),DSN=&&OBJ
//SYSLMOD  DD DISP=SHR,DSN=&HLQ..LOADLIB(BNKMAIN)
//RUN      EXEC PGM=BNKMAIN,COND=(4,LT,LINK)
//STEPLIB  DD DISP=SHR,DSN=&HLQ..LOADLIB
//ACCOUNT  DD DISP=SHR,DSN=&HLQ..ACCOUNT.MASTER
//TRANS    DD DISP=SHR,DSN=&HLQ..TXN.DAILY
//ACCPT    DD DSN=&HLQ..ACCEPTED(+1),DISP=(NEW,CATLG,DELETE)
//REJECT   DD DSN=&HLQ..REJECTED(+1),DISP=(NEW,CATLG,DELETE)
//LEDGER   DD DSN=&HLQ..LEDGER(+1),DISP=(NEW,CATLG,DELETE)
//SYSOUT   DD SYSOUT=*
```

This is not runnable as-is. The local code uses GnuCOBOL dynamic `ASSIGN` names
built from environment variables and `LINE SEQUENTIAL` ASCII files. On z/OS the
same business paragraphs would need static `ASSIGN TO ACCOUNT`-style names,
appropriate record formats, EBCDIC handling, copybook concatenation, and
Enterprise COBOL compiler options. The dataset names, compiler procedure, load
library, and job card are placeholders.

The complete example under `examples/jcl/` is intentionally marked
**illustrative only**. It is excluded from the local GnuCOBOL workflow.

## Return Codes and Conditional JCL

A batch step can set a return code with `RETURN-CODE`. JCL `COND` parameters can
skip or run later steps based on earlier return codes. Common patterns:

- compile return code > 4: do not link;
- link return code > 4: do not run;
- reconciliation return code nonzero: fail the job or run an exception step;
- business rejections: usually a successful job with an exception report, not a
  JCL failure.

The local exit codes are `0` success, `8` integrity failure, and `12` fatal
infrastructure/configuration failure. They are intentionally distinct from
per-transaction rejection counts.

## Batch Processing Lifecycle

A production-style z/OS design would add:

1. scheduler submission and job class;
2. input generation selection and allocation;
3. account master backup/checkpoint;
4. validation and update steps;
5. reconciliation and balancing;
6. report distribution;
7. GDG rollover or output retention;
8. restart/rollback procedure;
9. SMF/RACF audit controls.

This repository implements the core data flow and local staging, but not
scheduler integration, generation data groups, SMF, RACF, or a crash-safe
restart.

## VSAM and DB2 Integration Concepts

### VSAM

A VSAM KSDS could replace the in-memory account table:

- key: account id (`ACC#######`);
- record: customer, status, type, balance, movement totals;
- access: random `READ`/`REWRITE` by account id;
- transaction boundary: VSAM record-level update is not a full business
  transaction across two accounts; a transfer needs explicit commit/rollback
  design (often DB2 or a batch restart protocol).

### DB2

A DB2 implementation would use:

- `ACCOUNT` table with account id, status, balance, currency, version;
- `LEDGER` table with transaction id, entry sequence, debit/credit, amount;
- `BATCH_RUN` and `BATCH_CONTROL` tables;
- `COMMIT`/`ROLLBACK` around one transaction or a controlled batch window;
- SQL codes and `SQLCA` checks instead of `FILE STATUS`.

The local project does not connect to DB2 and must not be described as having
DB2 durability.

## CICS Concepts

CICS is for online transaction processing. A CICS version would need:

- a transaction id (4 characters) and program;
- a communication area (COMMAREA) or channels/containers;
- VSAM/DB2 resource definitions;
- task-level syncpoint and recovery;
- security and terminal/session handling.

That is a different execution model from this batch. No CICS code is present.

## Zowe CLI and z/OSMF

The optional workflow uses the supported `zowe zos-files` commands:

```text
zowe zos-files list uss-files <USS_DIR>
zowe zos-files upload file-to-uss <local> <remote> --binary --make-dir
zowe zos-files download uss-file <remote> --binary --file <local>
```

Connection values can be supplied through the supported `ZOWE_OPT_*`
environment variables (for example `ZOWE_OPT_HOST`, `ZOWE_OPT_PORT`,
`ZOWE_OPT_USER`, `ZOWE_OPT_PASSWORD`). Passwords are never written into the
repository.

The workflow requires repository secrets and manual dispatch. It verifies that
uploaded source bytes can be downloaded back byte-for-byte. It does **not**
submit JCL, compile, link, or execute anything. An upload alone is not proof of
z/OS compilation or execution.

Required repository secrets:

| Secret | Meaning |
|---|---|
| `ZOS_HOST` | z/OSMF test hostname |
| `ZOS_PORT` | z/OSMF TLS port |
| `ZOS_USER` | Dedicated test user |
| `ZOS_PASSWORD` | Dedicated test password or token value |

Optional repository variables:

| Variable | Default | Meaning |
|---|---|---|
| `ZOS_REJECT_UNAUTHORIZED` | `true` | Reject self-signed certificates |
| `ZOS_PROTOCOL` | `https` | z/OSMF protocol |

To run it: Actions → **Optional IBM z/OS Upload Integration** → **Run
workflow**, enter a pre-created dedicated USS directory such as
`/u/<user>/cobol-banking-ci`, confirm it is non-production, and supply the
secrets. The workflow refuses `/`, `/tmp`, and `/u` and only permits a restricted
absolute path character set. It fails preflight rather than pretending a
missing-secret run succeeded.

The command names and help output for `list uss-files`, `upload file-to-uss`, and
`download uss-file` were checked locally against Zowe CLI 8.41.1. No z/OSMF
connection, authentication, or upload was attempted, so the workflow remains
**unverified end to end**.

## Differences Between GnuCOBOL and IBM Enterprise COBOL

| Area | Local GnuCOBOL | IBM Enterprise COBOL |
|---|---|---|
| File names | `ASSIGN TO` data item built from environment paths | static DD names |
| File organization | line sequential ASCII | fixed/variable sequential, VSAM, DB2 |
| Copybooks | `COPY "NAME.cpy"` with `-I` | PDS members/SYSLIB |
| Compiler | `cobc` | `IGYCRCTL` |
| Linkage | single executable with `cobc -x` | object decks, binder, load library |
| Runtime | environment variables and process exit | JCL, step return codes, subsystems |
| Character set | ASCII | EBCDIC |
| `COMP-3` | six bytes for `S9(9)V99` | six bytes; binary representation platform-defined |
| Intrinsic functions | GnuCOBOL 3.2 implementations | Enterprise COBOL equivalents; verify version |
| Testing | local unit/integration harness | z/OS unit test frameworks, COBOL Check, batch test data |

The business logic is intentionally plain COBOL: `EVALUATE`, `IF`, `PERFORM`,
`STRING`, `UNSTRING`, `COMP-3`, `CALL`, and copybooks. The largest portability
gap is file control and runtime configuration, not arithmetic.

## Portability Work for a Real z/OS Run

1. Replace dynamic `ASSIGN` with static DD names.
2. Convert ASCII files to EBCDIC/appropriate record format.
3. Replace `LINE SEQUENTIAL` with sequential/VSAM organization.
4. Provide JCL `JOB`, `EXEC`, and `DD` statements and site compiler procedures.
5. Replace environment configuration with `PARM`/control cards or site tables.
6. Review `FUNCTION` support in the site compiler version.
7. Add dataset allocation, GDG, backup, and restart procedures.
8. Run a real compile/link/execution and inspect return codes and output.
9. Obtain security/compliance review; this project is not certified.

## What Is Actually Verified

- Local GnuCOBOL 3.2.0 build, unit tests, integration tests, and demo.
- Local deterministic output and independent reconciliation.
- YAML and documentation validation.

Not verified:

- z/OS compilation or JCL;
- VSAM/DB2/CICS integration;
- Zowe/z/OSMF connectivity;
- any production security or regulatory control.

IBM and IBM Z are trademarks of International Business Machines Corporation.
This project is not sponsored or endorsed by IBM.
