# Example z/OS JCL

**These examples are illustrative only.** They are not part of the local
GnuCOBOL build, they are not executed by CI, and they have not been tested on
z/OS. Dataset names, compiler procedures, classes, and storage parameters are
placeholders.

The local COBOL programs use:

- GnuCOBOL dynamic `ASSIGN TO` paths built from environment variables;
- `LINE SEQUENTIAL` ASCII files;
- `cobc` and a local executable.

A real z/OS port requires static DD names, EBCDIC/record-format handling,
Enterprise COBOL compiler options, a load library, and a site-specific
compile/link procedure. The business paragraphs are intended to be portable, but
the file-control layer is not.

## Prerequisites

- An authorized z/OS test environment and site COBOL compiler procedure.
- A partitioned data set for COBOL sources, e.g. `HLQ.COBOL`.
- A copybook PDS, e.g. `HLQ.COPYLIB`.
- A load library, e.g. `HLQ.LOADLIB`.
- Test sequential data sets for accounts/transactions and run-specific outputs.
- RACF/security authorization for the test datasets.
- Do not use production data or production libraries.

## Placeholders

| Placeholder | Meaning |
|---|---|
| `HLQ` | Your test high-level qualifier |
| `COBPROC` | Site compiler/link procedure name |
| `JOB CLASS` | Site batch class |
| `ACCT` | Site accounting code |

## What must change

1. `ASSIGN TO WS-...` must become static DD names, with matching JCL `DD`
   statements.
2. `LINE SEQUENTIAL` input/output must become the site's sequential/VSAM
   organization.
3. Character encoding and record padding must be defined.
4. Environment-based configuration must become `PARM` or control cards.
5. `BNKSETTL`/`BNKRPT` need allocations for settlement, reconciliation, and
   report data sets.
6. Use the site's compiler procedure; `IGYCRCTL`/`IEWL` are illustrative.
7. Add a job scheduler and restart policy.
8. Run actual compile, link, and execution tests; an upload is not proof.

## Source members

Upload/hand-copy these as text members into the source PDS:

```text
BNKMAIN
BNKVALID
BNKPROC
BNKSETTL
BNKRPT
```

Copybooks go into the copybook PDS:

```text
ACCOUNT
TRANSACT
LEDGER
INTERFACES
```

Because the local files use free format, compiler options must enable free
source. The local dynamic `ASSIGN` usage will not compile or run unchanged on
Enterprise COBOL without the file-control work described above.

## Return codes

- The local program sets `RETURN-CODE` to `0`, `8`, or `12`.
- On z/OS, a step return code is interpreted by JCL `COND` and the scheduler.
- A business rejection is not the same as a failed job; it is an exception
  record and should normally leave the job successful if reconciliation passes.

## Related documentation

- [Mainframe mapping](../../docs/MAINFRAME_MAPPING.md)
- [COBOL guide](../../docs/COBOL_GUIDE.md)
- [Known limitations](../../docs/KNOWN_LIMITATIONS.md)
