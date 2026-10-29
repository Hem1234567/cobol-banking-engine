# Troubleshooting

## Build Problems

### `cobc: command not found`

Install GnuCOBOL or set `COBC` to the compiler executable:

```bash
sudo apt-get install gnucobol
cobc --version
```

On Windows, put the GnuCOBOL `bin` directory on `PATH` or place a portable tree
at `.tools/gnucobol/`. `scripts/build.sh` looks for `cobc.exe` there.

### GnuCOBOL exits with a missing `libcob` DLL

The compiler is present but the runtime DLL is not on `PATH`. Add the compiler's
`bin` directory to `PATH` and rerun. Verify:

```bash
cobcrun --version
```

### `COB_CONFIG_DIR` errors

Portable GnuCOBOL builds need their configuration directory. The scripts set
`COB_CONFIG_DIR` for `.tools/gnucobol`; for another install, set it explicitly:

```bash
export COB_CONFIG_DIR=/path/to/gnucobol/config
```

### Python not found / Microsoft Store alias

A Windows `python3.exe` app-execution alias can open the Store instead of
running Python. The scripts test the interpreter before using it. Set a real
interpreter explicitly:

```bash
export PYTHON=/c/Users/<you>/AppData/Local/Programs/Python/Python310/python.exe
```

Python 3.10 or newer is required by the type syntax in the test harness.

### Compiler warning treated as failure

`scripts/build.sh` fails if the compiler emits a warning. Read
`build/logs/compile.log`. Do not suppress a warning without understanding it.
If a different GnuCOBOL version emits a version-specific warning, fix the source
or record the version compatibility issue explicitly.

On some Ubuntu GnuCOBOL packages, `cobc --info` contains both
`-D_FORTIFY_SOURCE=2` and `-D_FORTIFY_SOURCE=3`; GCC then emits
`_FORTIFY_SOURCE redefined` for every generated C module. This is a
distribution-package configuration issue, not a COBOL source warning. The
scripts override `COB_CFLAGS` on Linux with a single definition when the caller
has not supplied flags. If you set `COB_CFLAGS` yourself, make sure it contains
only one `_FORTIFY_SOURCE` definition.

### ShellCheck is not installed

```bash
sudo apt-get install shellcheck
shellcheck -x scripts/*.sh
```

The required CI validate job installs ShellCheck from the Ubuntu package
archive.

## Runtime Problems

### `BATCH|REFUSED|RUN_STATUS_ALREADY_EXISTS`, `RUN_FAILURE_ALREADY_EXISTS`, or `RUN_LOCK_ALREADY_EXISTS`

The output directory already contains a completed run, a failed diagnostic marker,
or an attempted run. Existing failure diagnostics are not a clean workspace. Use a new
directory, or remove the old directory only when you explicitly intend to
discard it:

```bash
rm -rf .work/manual-run
mkdir -p .work/manual-run
```

The provided scripts always use clean staging directories.

### Output directory missing

The COBOL program does not create arbitrary directories. Create it first:

```bash
mkdir -p output/demo
```

or use `scripts/run_demo.sh`, which creates `.work/demo-stage`.

### Exit code 12 with `run_failure.dat`

Read `run_failure.dat`. Common codes:

| Code | Cause |
|---|---|
| `C0001` | output directory missing/too long |
| `C0002` | run id blank, too long, or contains `|` |
| `C0003` | invalid `BNK_PROCESS_DATE` |
| `C0004` | currency is not three alphabetic characters |
| `F0020` | account master missing/unopenable |
| `F0030` | transaction file missing/unopenable |
| `F00xx` | output file open/write/close failure |
| `S00xx` | settlement input/output failure |

Exit `12` is a fatal infrastructure/configuration condition, not a business
rejection. Business rejections leave the exit code at `0` when the batch
reconciles.

### Exit code 8

Reconciliation found an inconsistency. Inspect:

```text
reconciliation.dat
settlement.dat
run_failure.dat
```

Do not "fix" the test by deleting checks. Determine whether an output file was
modified, a ledger entry is missing, or a total is wrong.

### No `run_status.dat` after a run

That is expected for a failed batch. Inspect `run_failure.dat`. A success marker
is written only after settlement and report generation succeed.

### `E0001` for a line that looks valid

Check:

- trailing material makes the line longer than 80 bytes;
- the line is shorter than 55 bytes;
- the amount is not at positions 43-55;
- the record was copied from an editor that added characters.

The input format is fixed-position, not comma-separated.

### Amount rejected as `E0005`

The only accepted amount shape is:

```text
+000000250.00
-000000025.00
```

A leading `+` is required for positive values. Commas, spaces in the digits,
more or fewer than two decimal places, and unsigned values are rejected.

### Account file records rejected

- Account id must be `ACC` + 7 digits.
- Status must be `A` or `C`.
- Type must be `CH` or `SV`.
- Opening balance must be `ddddddddd.dd`, non-negative.
- A duplicate account id uses the first record and rejects later occurrences.
- Check `account_exceptions.dat` for `A0001`-`A0007`.

### Files look shorter than the declared record length

`LINE SEQUENTIAL` trims trailing spaces from physical lines. Fixed fields before
the trimmed suffix remain in place, and readers pad records back to their
declared width. This is expected. Do not append arbitrary trailing data; it can
make the logical record over-long and rejected.

### Windows path issues in Git Bash

The native COBOL executable receives the working directory and relative paths;
using relative fixture paths is the most reliable choice. If you pass an
absolute POSIX path, convert it with `cygpath -m` for the native executable.
The scripts use relative paths deliberately.

## Test Problems

### Unit driver compile warning

The test harness treats warnings as failure. Fix the source or use a compiler
version known to be compatible. The production build is also warning-free.

### Test results show a failure in the Python verifier

Read the failure text and the retained scenario under
`build/test-work/<case>/`. Common causes:

- an expected fixture value became stale after a business-rule change;
- the app was not rebuilt (`./scripts/build.sh`);
- someone modified output files before verification;
- a report path or report name changed.

Do not alter the verifier to accept an inconsistent ledger. Fix the cause.

### Demo verification failure

The staging directory is moved to `output/failed/demo` and any success marker is
renamed. Inspect:

```text
output/failed/demo/run_failure.dat
output/failed/demo/settlement.dat
output/failed/demo/reconciliation.dat
```

Then rerun `./scripts/run_demo.sh` after fixing the defect.

### GitHub Actions test artifact upload

The upload step uses `if: always()` and `if-no-files-found: warn`; it does not
hide a failed test. Check the job log and the `cobol-test-results` artifact.

## CI Problems

### `python3-yaml` missing

Install PyYAML locally or in the runner:

```bash
sudo apt-get install -y python3-yaml
# or: python3 -m pip install pyyaml
python3 scripts/validate_yaml.py
```

### YAML validator reports duplicate keys

PyYAML's default loader silently overwrites duplicate mapping keys. The custom
loader in `scripts/validate_yaml.py` reports them. Fix the workflow; do not
weaken the check.

### ShellCheck failure

Run the same command locally:

```bash
shellcheck -x scripts/*.sh
```

Fix quoting, command substitutions, and `set -euo pipefail` issues rather than
suppressing errors.

### Documentation validation failure

`scripts/validate_docs.py` checks README links, required sections, documented
commands, and unverified-claim language. Update the documentation rather than
removing checks.

## Mainframe Problems

### Optional Zowe workflow fails immediately

Check the repository secrets and variables listed in
[MAINFRAME_MAPPING.md](MAINFRAME_MAPPING.md). The workflow is manual-only and
has not been validated against a real z/OS environment. A failure does not
affect the required CI workflow.

### Upload succeeds but compilation fails

An upload is not a compile. The local code uses GnuCOBOL-specific file
assignment and line-sequential ASCII files. Use the portability checklist in
[MAINFRAME_MAPPING.md](MAINFRAME_MAPPING.md) before attempting z/OS compilation.

### `COBOL Check` not found

The project does not require COBOL Check. It uses `src/test/cobol` and the Python
test harness because no compatible verified COBOL Check was available. See
[KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md).
