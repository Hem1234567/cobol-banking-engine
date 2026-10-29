# Security and Data-Handling Policy

## Scope

This is a fictional learning and portfolio project. It is **not a certified
banking platform**, not a production service, and not a compliance control. Do
not use it with real account numbers, customer information, payment records, or
production systems.

## Data Policy

- All account ids, customer references, transactions, and balances are
  fictional.
- No real bank account, network service, database, or mainframe is required.
- Sample records are deterministic and committed for review.
- Generated reports and batch outputs are ignored by Git except for
  `output/.gitkeep`.
- Do not put personal, customer, card, payment, or production data into the
  repository, test fixtures, issues, or CI logs.

## Credentials

The required build, tests, and demo use **no credentials**. Do not add:

- passwords;
- API keys;
- OAuth tokens;
- private keys;
- real hostnames or connection strings;
- production dataset names.

The optional z/OS upload workflow requires repository secrets, is manually
dispatched, and is excluded from required CI. Its values must be dedicated
test-environment credentials with the least privilege needed to upload to a
dedicated USS directory. It must never point at production data.

## CI Permissions

The required workflow declares:

```yaml
permissions:
  contents: read
```

It does not request `write` permissions, does not use repository secrets, and
does not use `continue-on-error` to hide failures.

## Secrets Handling in the Optional Workflow

- Secrets are supplied through GitHub repository secrets and mapped to
  `ZOWE_OPT_*` environment variables at job runtime.
- Values are not echoed to logs.
- The preflight job fails if required values are missing; it does not silently
  report a successful integration.
- The workflow only uploads source files to a caller-supplied dedicated USS
  directory and verifies a binary download round-trip.
- Upload is not compilation and is not execution.

If a secret is exposed, rotate it immediately and remove it from the affected
logs. GitHub masking is not a substitute for proper credential management.

## Input and Path Handling

- Record lengths and field formats are validated before use.
- Account ids and transaction ids must match explicit patterns.
- Amounts are parsed as exact decimal text and range-checked.
- Fixed-capacity tables have explicit limits and fatal overflows.
- Shell scripts quote paths and use `set -euo pipefail`.
- Paths come from environment variables; no shell `eval` is used.
- The output directory must already exist; the application does not create
  arbitrary directories.
- A run marker prevents accidental replay into an existing output set. The
  marker is advisory, not an OS lock.

## Output and Auditability

- `ledger.dat` is the auditable movement record; text reports are derived views.
- `batch_control.dat` records counts for independent comparison.
- `settlement.dat` and `reconciliation.dat` contain machine-readable controls.
- `run_status.dat` is written only after reconciliation and report generation.
- A failed run writes `run_failure.dat` and does not publish `run_status.dat`.

These controls demonstrate accounting integrity within the scope of the
simulator. They do not provide cryptographic immutability, write-once storage,
digital signatures, or regulatory audit evidence.

## What This Project Does Not Claim

- PCI DSS, SOX, GDPR, PSD2, or any regulatory certification.
- Production-grade availability, durability, or disaster recovery.
- Real mainframe security controls (RACF, SMF, SAF).
- Encryption at rest or in transit.
- Protection against a malicious local operator with filesystem access.

## Reporting Problems

For a real deployment, a security review, threat model, secret manager,
least-privilege service identities, encryption, audit logging, and incident
response plan would be required. This repository is not appropriate for real
financial data.
