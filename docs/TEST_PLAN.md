# Test Plan

## Test Strategy

The test suite has three layers:

1. **Portable COBOL unit tests** (`src/test/cobol/`) call `BNKVALID` and
   `BNKPROC` directly with in-memory account tables. They assert status, error
   code, balances, movement totals, and ledger entries without file I/O.
2. **Deterministic integration scenarios** (`tests/run_tests.py`) execute the
   compiled `bnkapp` against generated/committed fixed-width fixtures.
3. **Independent output verification** (`tests/banking_checks.py`) parses the
   output records, recomputes ledger and account equations, checks counts and
   totals, and compares them to `settlement.dat`. It never trusts the application
   counters.

All tests run without network access, credentials, a database, or a mainframe.
Each scenario uses a clean workspace under `build/test-work/`.

COBOL Check is **not** used. No compatible, operational COBOL Check installation
was available in this environment, so the repository uses a verified portable
COBOL test harness instead. This limitation is stated in
[KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md).

## COBOL Unit Tests

### `TESTVALID.CBL` — 19 cases

| Case | Expected |
|---|---|
| Valid deposit | accepted, amount 100.00 |
| Deposit larger than current balance | accepted; deposits do not require available funds |
| Valid withdrawal | accepted, amount 200.00 |
| Valid transfer | accepted, source/destination indexes set |
| Insufficient withdrawal | `E0014` |
| Insufficient transfer | `E0014` |
| Unknown destination | `E0012` |
| Closed source | `E0010` |
| Closed destination | `E0013` |
| Zero amount | `E0006` |
| Negative amount | `E0006` |
| Duplicate id in history | `E0003` |
| Unknown type | `E0004` |
| Malformed amount | `E0005` |
| Self transfer | `E0015` |
| Deposit with destination | `E0008` |
| Missing source | `E0007` |
| Invalid transaction id | `E0002` |
| Withdrawal of exact available balance | accepted |

Every case prints `PASS|...` or `FAIL|...`; a final `SUMMARY|TESTS=...|FAILURES=...`
lets the Python harness verify that the driver itself did not hide a failure.
The driver exits `1` if any case fails.

### `TESTPROC.CBL` — 9 cases

| Case | Expected |
|---|---|
| Deposit | balance +100, credit movement 100, one CREDIT ledger |
| Withdrawal | balance -250, debit movement 250, one DEBIT ledger |
| Transfer | source -300, destination +300, equal DEBIT/CREDIT |
| Insufficient withdrawal | `E0014`, balances and counters unchanged, no ledger |
| Insufficient transfer | `E0014`, both balances unchanged, no ledger |
| Closed account | `E0010`, no balance change |
| Invalid validation passed to processor | `E0017`, no mutation |
| Withdrawal of exact balance | accepted, balance becomes 0 |
| Deposit overflow | `E0016`, balance and ledger unchanged |

## Required Scenarios

### Integration Test Matrix

| Required scenario | Coverage |
|---|---|
| Valid deposit increases balance exactly | sample and invalid-account scenarios |
| Valid withdrawal decreases balance exactly | sample |
| Valid transfer debits/credits equally | sample, transfer ledger pair checked |
| Insufficient-funds withdrawal rejected | sample (`E0014`) |
| Insufficient-funds transfer rejected | sample (`E0014`) |
| Transfer to unknown account rejected | sample (`E0012`) |
| Closed account rejected | sample deposit to closed source (`E0010`), closed destination (`E0013`) |
| Zero amount rejected | sample (`E0006`) |
| Negative amount rejected | sample (`E0006`) |
| Duplicate id rejected without second balance update | sample sequence 9 (`E0003`), exact balances asserted |
| Unknown type rejected | sample (`E0004`) |
| Malformed transaction reported safely | short line and over-long generated line (`E0001`) |
| Empty transaction file | dedicated scenario, zero counts and balanced settlement |
| Invalid account master reported | dedicated scenario, `A0002`/`A0003`/`A0006` |
| Opening + movements = closing | independently recomputed per account |
| Ledger reconciles with movements | independently recomputed per account and in aggregate |
| Every transfer has matching debit/credit | paired by transaction id |
| Rejected transactions do not modify balances | exact account outputs and equations |
| Fatal file errors give nonzero exit | missing transaction file, exit `12` |
| Repeated demo deterministic | byte-for-byte comparison of two runs |

## Test Execution

```bash
./scripts/test.sh
```

If the app was already built:

```bash
BNK_SKIP_BUILD=1 ./scripts/test.sh
```

The harness writes:

```text
build/test-results.json
build/test-results.xml
build/test-work/
build/logs/compile.log
```

`test-results.xml` is JUnit-compatible for CI ingestion. The current local run
reports `SUMMARY|TESTS=36|FAILURES=0`.

## Expected Sample Results

The committed sample has 6 account records and 19 transaction records.

```text
accounts loaded      5
account exceptions   1   A0003 duplicate
input transactions   19
accepted             4   sequences 1, 2, 3, 10
rejected             15
ledger entries       5   accepted 4 + transfers 1
deposits             275.50
withdrawals          500.00
transfer value       300.00
accepted value       1,075.50
rejected nominal     4,844.00
ledger debits        800.00
ledger credits       575.50
opening total        9,350.00
closing total        9,125.50
net movement         -224.50
reconciliation       BALANCED
```

Rejected sequence/code pairs:

```text
000004 E0014   000005 E0014   000006 E0012   000007 E0010   000008 E0006
000009 E0003   000011 E0004   000012 E0005   000013 E0013   000014 E0009
000015 E0015   000016 E0001   000017 E0008   000018 E0006   000019 E0010
```

See [data/expected/sample_expected.txt](../data/expected/sample_expected.txt)
for the human-readable walkthrough.

## Independent Verification Details

`tests/banking_checks.py`:

- Parses fixed records with explicit field offsets.
- Requires status fields to be `ACCEPTED` or `REJECTED`.
- Requires valid IDs, amounts, and ledger types.
- Pairs every accepted transaction with its expected ledger entries.
- Verifies that no ledger row references an unknown account.
- Recomputes per-account debit/credit/count totals from the ledger.
- Compares every account's opening + credits - debits to closing.
- Recomputes deposit, withdrawal, transfer, accepted, rejected, ledger debit,
  ledger credit, opening, closing, and net movement totals.
- Compares those totals to `settlement.dat`.
- Checks `batch_control.dat` and `run_status.dat` counts.
- Checks all seven reconciliation rows are `PASS`.
- Checks all five reports exist and are nonempty, and that reports display
  `BALANCED`.

The Python verifier deliberately does not trust any application-produced report
or summary without recomputation.

## Fatal-Path Tests

The missing-transaction-file case verifies:

- nonzero process exit (`12`);
- `run_failure.dat` exists and says `status=FAILED`;
- `run_status.dat` does **not** exist;
- no implicit-close warning is emitted by the COBOL runtime.

The rerun case verifies that a second invocation against an existing successful
output directory is refused and that the first run's files remain unchanged.

## CI Mapping

| CI job | Test command | Evidence |
|---|---|---|
| validate | `validate_repo.py`, `validate_yaml.py`, `shellcheck` | structure/YAML/shell results |
| build | `scripts/build.sh` | compiler log, warning-free build |
| unit-integration-tests | `scripts/test.sh` | JSON/JUnit plus scenario output |
| end-to-end | `scripts/run_demo.sh`, `verify_demo.py`, hash comparison | published demo, determinism |
| documentation | `validate_docs.py` | links, required docs, credential-free CI |

## Manual Review Checklist

1. Inspect `ledger.dat` and confirm every transfer has two rows with the same
   transaction id and amount.
2. Confirm `accounts_out.dat` matches the independently expected balances.
3. Confirm `settlement.dat` is `BALANCED` and every check row is `PASS`.
4. Confirm `exception_report.txt` lists every rejected input.
5. Confirm a failed run has no `run_status.dat`.
6. Confirm the demo's second run is byte-identical.
7. Confirm no generated binaries or credentials are staged by Git.

## Not Covered

- z/OS compilation, JCL execution, VSAM, DB2, CICS, RACF, SMF.
- Concurrent processes and crash-safe transaction recovery.
- Real customer data, PCI DSS, SOX, GDPR, or regulatory compliance.
- Interest, fees, tax, FX, and rounding policies.
- COBOL Check execution.
- Zowe integration against a real z/OSMF endpoint.
