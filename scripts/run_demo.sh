#!/usr/bin/env bash
# Run the deterministic sample batch in a staging directory, verify it, and
# publish output/demo only after reconciliation and reports succeed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LOCAL_GC="$ROOT/.tools/gnucobol"
if [ -x "$LOCAL_GC/bin/cobc.exe" ] || [ -x "$LOCAL_GC/bin/cobc" ]; then
    export PATH="$LOCAL_GC/bin:$PATH"
    export COB_CONFIG_DIR="$LOCAL_GC/config"
fi

PYTHON="${PYTHON:-}"
if [ -z "$PYTHON" ]; then
    if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' >/dev/null 2>&1; then
        PYTHON="python3"
    elif command -v python >/dev/null 2>&1 && python -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' >/dev/null 2>&1; then
        PYTHON="python"
    else
        echo "DEMO|FAIL|Python 3.10 or newer was not found" >&2
        exit 127
    fi
fi

if [ "${BNK_SKIP_BUILD:-0}" != "1" ]; then
    "$ROOT/scripts/build.sh"
fi

APP=""
if [ -f "$ROOT/build/bin/bnkapp.exe" ]; then
    APP="$ROOT/build/bin/bnkapp.exe"
elif [ -f "$ROOT/build/bin/bnkapp" ]; then
    APP="$ROOT/build/bin/bnkapp"
fi
if [ -z "$APP" ]; then
    echo "DEMO|FAIL|build/bin/bnkapp is missing" >&2
    exit 1
fi

STAGE="$ROOT/.work/demo-stage"
PUBLISHED="$ROOT/output/demo"
FAILED="$ROOT/output/failed/demo"
rm -rf "$STAGE" "$FAILED"
rm -rf "$PUBLISHED"
mkdir -p "$STAGE" "$ROOT/output/failed"

export BNK_ACCOUNTS_FILE="data/sample/accounts.dat"
export BNK_TRANSACTIONS_FILE="data/sample/transactions.dat"
export BNK_OUTPUT_DIR=".work/demo-stage"
export BNK_RUN_ID="DEMORUN001"
export BNK_PROCESS_DATE="2026-01-15"
export BNK_CURRENCY="USD"

set +e
"$APP"
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
    if [ -d "$STAGE" ]; then
        rm -rf "$FAILED"
        mv "$STAGE" "$FAILED"
    fi
    echo "DEMO|FAIL|batch exit $RC; diagnostics preserved under output/failed/demo" >&2
    exit "$RC"
fi

if ! "$PYTHON" "$ROOT/tests/verify_demo.py" "$STAGE"; then
    if [ -f "$STAGE/run_status.dat" ]; then
        mv "$STAGE/run_status.dat" "$STAGE/run_status.rejected.dat"
    fi
    rm -rf "$FAILED"
    mv "$STAGE" "$FAILED"
    echo "DEMO|FAIL|independent output verification failed; see output/failed/demo" >&2
    exit 1
fi

mv "$STAGE" "$PUBLISHED"
echo "DEMO|SUCCESS|$PUBLISHED"
grep -E '^(accepted_transactions|rejected_transactions|ledger_entries|reconciliation_status)\|' \
    "$PUBLISHED/settlement.dat" || true
