"""Independent parsers and reconciliation checks for the COBOL batch outputs.

The checks in this module deliberately recompute totals from the fixed-width
output records instead of trusting settlement.dat or run_status.dat. They are
used both by the automated test suite and by the demo verifier.
"""

from __future__ import annotations

from decimal import Decimal
from pathlib import Path
import re
from typing import Any

MONEY_RE = re.compile(r"^[+-]\d{9}\.\d{2}$")
BALANCE_RE = re.compile(r"^\d{9}\.\d{2}$")
ACCOUNT_RE = re.compile(r"^ACC\d{7}$")
TXN_RE = re.compile(r"^TXN\d{9}$")

REPORT_FILES = (
    "daily_transaction_report.txt",
    "account_balance_report.txt",
    "exception_report.txt",
    "settlement_report.txt",
    "reconciliation_report.txt",
)


class VerificationError(AssertionError):
    """Raised when an output invariant is not satisfied."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise VerificationError(message)


def _pad(value: str, width: int) -> str:
    require(len(value) <= width, f"value too long for {width}-byte field: {value!r}")
    return value.ljust(width)


def account_line(account_id: str, customer: str, status: str, acct_type: str,
                 opening: str) -> str:
    require(BALANCE_RE.fullmatch(opening) is not None, f"bad opening balance {opening!r}")
    line = (
        _pad(account_id, 10)
        + _pad(customer, 12)
        + status
        + acct_type
        + opening
    )
    return _pad(line, 80)


def transaction_line(txn_id: str, txn_type: str, source: str, destination: str,
                     amount: str) -> str:
    require(MONEY_RE.fullmatch(amount) is not None, f"bad amount {amount!r}")
    line = (
        _pad(txn_id, 12)
        + _pad(txn_type, 10)
        + _pad(source, 10)
        + _pad(destination, 10)
        + amount
    )
    return _pad(line, 80)


def write_lines(path: Path, lines: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii", newline="\n") as handle:
        for line in lines:
            handle.write(line)
            handle.write("\n")


def read_fixed(path: Path, width: int) -> list[str]:
    if not path.exists():
        return []
    records: list[str] = []
    with path.open("r", encoding="ascii", errors="replace", newline="") as handle:
        for raw in handle:
            line = raw.rstrip("\r\n")
            if len(line) > width:
                require(False, f"{path.name}: record longer than {width}: {line!r}")
            records.append(line.ljust(width))
    return records


def parse_key_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    with path.open("r", encoding="ascii", errors="replace", newline="") as handle:
        for raw in handle:
            line = raw.rstrip("\r\n")
            if not line:
                continue
            segments = line.split("|")
            if len(segments) > 1 and all("=" in segment for segment in segments):
                for segment in segments:
                    key, value = segment.split("=", 1)
                    values[key.strip()] = value.strip()
            elif "|" in line:
                key, value = line.split("|", 1)
                values[key.strip()] = value.strip()
            elif "=" in line:
                key, value = line.split("=", 1)
                values[key.strip()] = value.strip()
    return values


def read_reconciliation(path: Path) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    if not path.exists():
        return rows
    with path.open("r", encoding="ascii", errors="replace", newline="") as handle:
        for raw in handle:
            line = raw.rstrip("\r\n")
            if not line:
                continue
            parts = line.split("|")
            if parts[0] == "check" and len(parts) >= 3:
                rows.append({
                    "type": "check",
                    "name": parts[1],
                    "result": parts[2],
                    "detail": parts[3] if len(parts) > 3 else "",
                })
            elif parts[0] == "overall" and len(parts) >= 2:
                rows.append({
                    "type": "overall",
                    "name": "overall",
                    "result": parts[1],
                    "detail": parts[2] if len(parts) > 2 else "",
                })
    return rows


def parse_accepted(path: Path) -> list[dict[str, Any]]:
    result = []
    for record in read_fixed(path, 100):
        item = {
            "id": record[0:12],
            "sequence": record[12:18],
            "type": record[18:28].strip(),
            "source": record[28:38],
            "destination": record[38:48],
            "amount_text": record[48:61],
            "status": record[61:69].strip(),
            "source_balance_text": record[69:81],
            "destination_balance_text": record[81:93],
        }
        require(TXN_RE.fullmatch(item["id"]) is not None,
                f"accepted record has invalid id {item['id']!r}")
        require(item["status"] == "ACCEPTED",
                f"accepted record {item['id']} has status {item['status']!r}")
        require(MONEY_RE.fullmatch(item["amount_text"]) is not None,
                f"accepted record {item['id']} has invalid amount")
        item["amount"] = Decimal(item["amount_text"])
        item["source_balance"] = Decimal(item["source_balance_text"])
        if item["type"] == "TRANSFER":
            require(BALANCE_RE.fullmatch(item["destination_balance_text"]) is not None,
                    f"transfer {item['id']} lacks destination balance")
            item["destination_balance"] = Decimal(item["destination_balance_text"])
        result.append(item)
    return result


def parse_rejected(path: Path) -> list[dict[str, Any]]:
    result = []
    for record in read_fixed(path, 124):
        item = {
            "id": record[0:12],
            "type": record[12:22].strip(),
            "source": record[22:32],
            "destination": record[32:42],
            "amount_text": record[42:55].strip(),
            "error": record[55:61].strip(),
            "status": record[61:69].strip(),
            "sequence": record[69:75],
            "detail": record[75:123].strip(),
        }
        require(item["status"] == "REJECTED",
                f"rejected record has status {item['status']!r}")
        require(bool(item["error"]), "rejected record has no error code")
        result.append(item)
    return result


def parse_ledger(path: Path) -> list[dict[str, Any]]:
    result = []
    for record in read_fixed(path, 100):
        item = {
            "id": record[0:12],
            "transaction_id": record[12:24],
            "entry_type": record[24:30].strip(),
            "account": record[30:40],
            "counterparty": record[40:50].strip(),
            "amount_text": record[50:63],
            "date": record[63:73],
            "run_id": record[73:83].strip(),
        }
        require(item["entry_type"] in {"DEBIT", "CREDIT"},
                f"ledger {item['id']} has invalid type {item['entry_type']!r}")
        require(MONEY_RE.fullmatch(item["amount_text"]) is not None,
                f"ledger {item['id']} has invalid amount")
        item["amount"] = Decimal(item["amount_text"])
        result.append(item)
    return result


def parse_accounts(path: Path) -> list[dict[str, Any]]:
    result = []
    for record in read_fixed(path, 100):
        item = {
            "id": record[0:10],
            "customer": record[10:22],
            "status": record[22],
            "type": record[23:25],
            "opening_text": record[25:37],
            "closing_text": record[37:49],
            "debits_text": record[49:61],
            "credits_text": record[61:73],
            "count_text": record[73:79],
        }
        require(ACCOUNT_RE.fullmatch(item["id"]) is not None,
                f"account summary has invalid id {item['id']!r}")
        for field in ("opening_text", "closing_text", "debits_text", "credits_text"):
            require(BALANCE_RE.fullmatch(item[field]) is not None,
                    f"account {item['id']} has invalid {field}")
        require(item["count_text"].isdigit(), "account count is not numeric")
        item["opening"] = Decimal(item["opening_text"])
        item["closing"] = Decimal(item["closing_text"])
        item["debits"] = Decimal(item["debits_text"])
        item["credits"] = Decimal(item["credits_text"])
        item["count"] = int(item["count_text"])
        result.append(item)
    return result


def parse_exceptions(path: Path) -> list[dict[str, Any]]:
    result = []
    for record in read_fixed(path, 100):
        item = {
            "id": record[0:10],
            "customer": record[10:22],
            "error": record[22:28].strip(),
            "status": record[28:36].strip(),
            "detail": record[36:84].strip(),
        }
        require(item["status"] == "REJECTED",
                f"account exception has status {item['status']!r}")
        require(bool(item["error"]), "account exception has no error code")
        result.append(item)
    return result


def _decimal_or_zero(value: str) -> Decimal:
    return Decimal(value) if MONEY_RE.fullmatch(value) else Decimal("0.00")


def verify_success(outdir: Path, transactions_input: Path,
                   expected: dict[str, Any] | None = None) -> dict[str, Any]:
    """Verify a successful batch using only its output records plus input count."""

    run_status = parse_key_values(outdir / "run_status.dat")
    require(run_status.get("status") == "SUCCESS",
            f"run_status is not SUCCESS: {run_status}")
    require(not (outdir / "run_failure.dat").exists(),
            "a successful run must not contain run_failure.dat")

    settlement = parse_key_values(outdir / "settlement.dat")
    control = parse_key_values(outdir / "batch_control.dat")
    recon = read_reconciliation(outdir / "reconciliation.dat")
    accepted = parse_accepted(outdir / "accepted.dat")
    rejected = parse_rejected(outdir / "rejected.dat")
    ledger = parse_ledger(outdir / "ledger.dat")
    accounts = parse_accounts(outdir / "accounts_out.dat")
    exceptions = parse_exceptions(outdir / "account_exceptions.dat")

    require(settlement.get("reconciliation_status") == "BALANCED",
            "settlement status is not BALANCED")
    require(control.get("run_id") == settlement.get("run_id"),
            "control and settlement run ids differ")
    require(control.get("process_date") == settlement.get("process_date"),
            "control and settlement dates differ")

    overall = [row for row in recon if row["type"] == "overall"]
    require(len(overall) == 1, "reconciliation must contain exactly one overall row")
    require(overall[0]["result"] == "PASS", "overall reconciliation is not PASS")
    checks = [row for row in recon if row["type"] == "check"]
    require(len(checks) == 7, f"expected seven reconciliation checks, got {len(checks)}")
    for row in checks:
        require(row["result"] == "PASS", f"reconciliation check {row['name']} is {row['result']}")

    input_records = 0
    if transactions_input.exists():
        input_records = len(transactions_input.read_text(encoding="ascii").splitlines())
    require(len(accepted) + len(rejected) == input_records,
            f"input count {input_records} != accepted {len(accepted)} + rejected {len(rejected)}")

    account_ids = {account["id"] for account in accounts}
    require(len(account_ids) == len(accounts), "duplicate account ids in account summary")

    ledger_by_txn: dict[str, list[dict[str, Any]]] = {}
    for entry in ledger:
        require(entry["account"] in account_ids,
                f"ledger references unknown account {entry['account']!r}")
        ledger_by_txn.setdefault(entry["transaction_id"], []).append(entry)

    deposit_total = Decimal("0.00")
    withdrawal_total = Decimal("0.00")
    transfer_total = Decimal("0.00")
    transfer_count = 0
    accepted_total = Decimal("0.00")
    for item in accepted:
        amount = item["amount"]
        require(amount > 0, f"accepted amount is not positive for {item['id']}")
        accepted_total += amount
        entries = ledger_by_txn.get(item["id"], [])
        if item["type"] == "DEPOSIT":
            deposit_total += amount
            require(len(entries) == 1, f"deposit {item['id']} must have one ledger entry")
            require(entries[0]["entry_type"] == "CREDIT", "deposit ledger entry must be CREDIT")
            require(entries[0]["account"] == item["source"], "deposit ledger account mismatch")
            require(entries[0]["amount"] == amount, "deposit ledger amount mismatch")
        elif item["type"] == "WITHDRAWAL":
            withdrawal_total += amount
            require(len(entries) == 1, f"withdrawal {item['id']} must have one ledger entry")
            require(entries[0]["entry_type"] == "DEBIT", "withdrawal ledger entry must be DEBIT")
            require(entries[0]["account"] == item["source"], "withdrawal ledger account mismatch")
            require(entries[0]["amount"] == amount, "withdrawal ledger amount mismatch")
        elif item["type"] == "TRANSFER":
            transfer_total += amount
            transfer_count += 1
            require(len(entries) == 2, f"transfer {item['id']} must have two ledger entries")
            debits = [entry for entry in entries if entry["entry_type"] == "DEBIT"]
            credits = [entry for entry in entries if entry["entry_type"] == "CREDIT"]
            require(len(debits) == 1 and len(credits) == 1,
                    f"transfer {item['id']} must have one debit and one credit")
            require(debits[0]["account"] == item["source"], "transfer debit account mismatch")
            require(credits[0]["account"] == item["destination"],
                    "transfer credit account mismatch")
            require(debits[0]["amount"] == credits[0]["amount"] == amount,
                    "transfer debit/credit amounts differ")
        else:
            require(False, f"accepted record has unsupported type {item['type']!r}")

    require(len(ledger_by_txn) == len(accepted),
            "ledger contains transaction ids that are not accepted")
    require(len(ledger) == len(accepted) + transfer_count,
            "ledger count must equal accepted count plus transfer count")

    rejected_total = sum(
        (abs(_decimal_or_zero(item["amount_text"])) for item in rejected),
        Decimal("0.00"),
    )

    ledger_debits = sum(
        (entry["amount"] for entry in ledger if entry["entry_type"] == "DEBIT"),
        Decimal("0.00"),
    )
    ledger_credits = sum(
        (entry["amount"] for entry in ledger if entry["entry_type"] == "CREDIT"),
        Decimal("0.00"),
    )

    debits_by_account: dict[str, Decimal] = {account_id: Decimal("0.00") for account_id in account_ids}
    credits_by_account: dict[str, Decimal] = {account_id: Decimal("0.00") for account_id in account_ids}
    count_by_account: dict[str, int] = {account_id: 0 for account_id in account_ids}
    for entry in ledger:
        if entry["entry_type"] == "DEBIT":
            debits_by_account[entry["account"]] += entry["amount"]
        else:
            credits_by_account[entry["account"]] += entry["amount"]
        count_by_account[entry["account"]] += 1

    opening_total = Decimal("0.00")
    closing_total = Decimal("0.00")
    for item in accounts:
        account_id = item["id"]
        opening_total += item["opening"]
        closing_total += item["closing"]
        require(item["closing"] == item["opening"]
                + credits_by_account[account_id] - debits_by_account[account_id],
                f"account {account_id} does not reconcile")
        require(item["debits"] == debits_by_account[account_id],
                f"account {account_id} debit total mismatch")
        require(item["credits"] == credits_by_account[account_id],
                f"account {account_id} credit total mismatch")
        require(item["count"] == count_by_account[account_id],
                f"account {account_id} movement count mismatch")

    expected_movement = deposit_total - withdrawal_total
    require(closing_total - opening_total == expected_movement,
            "closing minus opening does not equal deposits minus withdrawals")
    require(ledger_credits - ledger_debits == expected_movement,
            "ledger net movement does not equal deposits minus withdrawals")

    def sdecimal(key: str) -> Decimal:
        value = settlement.get(key)
        require(value is not None, f"settlement field {key} is missing")
        return Decimal(value)

    def sint(key: str) -> int:
        value = settlement.get(key)
        require(value is not None and value.strip().isdigit(),
                f"settlement field {key} is not numeric")
        return int(value)

    require(sint("input_transactions") == input_records, "settlement input count mismatch")
    require(sint("accepted_transactions") == len(accepted), "settlement accepted count mismatch")
    require(sint("rejected_transactions") == len(rejected), "settlement rejected count mismatch")
    require(sint("ledger_entries") == len(ledger), "settlement ledger count mismatch")
    require(sint("transfers") == transfer_count, "settlement transfer count mismatch")
    require(sint("accounts") == len(accounts), "settlement account count mismatch")
    require(sint("account_rejections") == len(exceptions),
            "settlement account rejection count mismatch")
    require(sdecimal("deposits") == deposit_total, "settlement deposit total mismatch")
    require(sdecimal("withdrawals") == withdrawal_total, "settlement withdrawal total mismatch")
    require(sdecimal("transfer_amount") == transfer_total, "settlement transfer total mismatch")
    require(sdecimal("accepted_amount") == accepted_total, "settlement accepted total mismatch")
    require(sdecimal("rejected_amount") == rejected_total, "settlement rejected total mismatch")
    require(sdecimal("ledger_debits") == ledger_debits, "settlement ledger debit total mismatch")
    require(sdecimal("ledger_credits") == ledger_credits, "settlement ledger credit total mismatch")
    require(sdecimal("opening_balance") == opening_total, "settlement opening total mismatch")
    require(sdecimal("closing_balance") == closing_total, "settlement closing total mismatch")
    require(sdecimal("net_movement") == closing_total - opening_total,
            "settlement net movement mismatch")

    require(int(control.get("input_transactions", "0")) == input_records,
            "control input count mismatch")
    require(int(control.get("accepted_transactions", "0")) == len(accepted),
            "control accepted count mismatch")
    require(int(control.get("rejected_transactions", "0")) == len(rejected),
            "control rejected count mismatch")
    require(int(control.get("ledger_entries", "0")) == len(ledger),
            "control ledger count mismatch")
    require(int(control.get("accounts_loaded", "0")) == len(accounts),
            "control account count mismatch")
    require(int(control.get("account_rejections", "0")) == len(exceptions),
            "control account rejection count mismatch")

    require(int(run_status.get("accepted_count", "0")) == len(accepted),
            "run_status accepted count mismatch")
    require(int(run_status.get("rejected_count", "0")) == len(rejected),
            "run_status rejected count mismatch")
    require(run_status.get("reconciliation_status") == "BALANCED",
            "run_status reconciliation status mismatch")

    for name in REPORT_FILES:
        path = outdir / name
        require(path.exists() and path.stat().st_size > 0,
                f"report {name} is missing or empty")
    require("BALANCED" in (outdir / "settlement_report.txt").read_text(encoding="ascii"),
            "settlement report does not show BALANCED")
    require("OVERALL RECONCILIATION: BALANCED"
            in (outdir / "reconciliation_report.txt").read_text(encoding="ascii"),
            "reconciliation report does not show overall BALANCED")

    summary = {
        "accounts": accounts,
        "accepted": accepted,
        "rejected": rejected,
        "ledger": ledger,
        "exceptions": exceptions,
        "input_records": input_records,
        "accepted_count": len(accepted),
        "rejected_count": len(rejected),
        "account_count": len(accounts),
        "exception_count": len(exceptions),
        "ledger_count": len(ledger),
        "transfer_count": transfer_count,
        "deposit_total": deposit_total,
        "withdrawal_total": withdrawal_total,
        "transfer_total": transfer_total,
        "accepted_total": accepted_total,
        "rejected_total": rejected_total,
        "ledger_debits": ledger_debits,
        "ledger_credits": ledger_credits,
        "opening_total": opening_total,
        "closing_total": closing_total,
        "net_movement": closing_total - opening_total,
    }

    if expected:
        _check_expected(summary, expected)
    return summary


def _check_expected(summary: dict[str, Any], expected: dict[str, Any]) -> None:
    for key in (
        "input_records", "accepted_count", "rejected_count", "account_count",
        "exception_count", "ledger_count", "transfer_count",
    ):
        if key in expected:
            require(summary[key] == expected[key],
                    f"expected {key}={expected[key]}, got {summary[key]}")

    for key in (
        "deposit_total", "withdrawal_total", "transfer_total", "accepted_total",
        "rejected_total", "ledger_debits", "ledger_credits", "opening_total",
        "closing_total", "net_movement",
    ):
        if key in expected:
            require(summary[key] == Decimal(expected[key]),
                    f"expected {key}={expected[key]}, got {summary[key]}")

    if "accounts" in expected:
        actual = {account["id"]: account for account in summary["accounts"]}
        for account_id, fields in expected["accounts"].items():
            require(account_id in actual, f"expected account {account_id} is missing")
            for field in ("opening", "closing", "debits", "credits"):
                if field in fields:
                    require(actual[account_id][field] == Decimal(fields[field]),
                            f"account {account_id} {field} expected {fields[field]}, "
                            f"got {actual[account_id][field]}")
            if "count" in fields:
                require(actual[account_id]["count"] == fields["count"],
                        f"account {account_id} count expected {fields['count']}")

    if "accepted_sequences" in expected:
        actual_sequences = sorted(item["sequence"] for item in summary["accepted"])
        require(actual_sequences == sorted(expected["accepted_sequences"]),
                f"accepted sequences expected {expected['accepted_sequences']}, "
                f"got {actual_sequences}")

    if "rejected_codes" in expected:
        actual_codes = {item["sequence"]: item["error"] for item in summary["rejected"]}
        require(actual_codes == expected["rejected_codes"],
                f"rejected codes differ: {actual_codes}")

    if "account_exception_codes" in expected:
        actual_codes = sorted(item["error"] for item in summary["exceptions"])
        require(actual_codes == sorted(expected["account_exception_codes"]),
                f"account exception codes expected {expected['account_exception_codes']}, "
                f"got {actual_codes}")


SAMPLE_EXPECTED: dict[str, Any] = {
    "input_records": 19,
    "accepted_count": 4,
    "rejected_count": 15,
    "account_count": 5,
    "exception_count": 1,
    "ledger_count": 5,
    "transfer_count": 1,
    "deposit_total": "275.50",
    "withdrawal_total": "500.00",
    "transfer_total": "300.00",
    "accepted_total": "1075.50",
    "rejected_total": "4844.00",
    "ledger_debits": "800.00",
    "ledger_credits": "575.50",
    "opening_total": "9350.00",
    "closing_total": "9125.50",
    "net_movement": "-224.50",
    "accounts": {
        "ACC0000001": {"opening": "5000.00", "closing": "4950.00",
                       "debits": "300.00", "credits": "250.00", "count": 2},
        "ACC0000002": {"opening": "2500.00", "closing": "2300.00",
                       "debits": "500.00", "credits": "300.00", "count": 2},
        "ACC0000003": {"opening": "1000.00", "closing": "1000.00",
                       "debits": "0.00", "credits": "0.00", "count": 0},
        "ACC0000004": {"opening": "750.00", "closing": "750.00",
                       "debits": "0.00", "credits": "0.00", "count": 0},
        "ACC0000005": {"opening": "100.00", "closing": "125.50",
                       "debits": "0.00", "credits": "25.50", "count": 1},
    },
    "accepted_sequences": ["000001", "000002", "000003", "000010"],
    "rejected_codes": {
        "000004": "E0014",
        "000005": "E0014",
        "000006": "E0012",
        "000007": "E0010",
        "000008": "E0006",
        "000009": "E0003",
        "000011": "E0004",
        "000012": "E0005",
        "000013": "E0013",
        "000014": "E0009",
        "000015": "E0015",
        "000016": "E0001",
        "000017": "E0008",
        "000018": "E0006",
        "000019": "E0010",
    },
    "account_exception_codes": ["A0003"],
}
