#!/usr/bin/env bash
# Build the application, compile COBOL unit tests, and run deterministic tests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LOCAL_GC="$ROOT/.tools/gnucobol"
COBC="${COBC:-}"
if [ -z "$COBC" ] && [ -x "$LOCAL_GC/bin/cobc.exe" ]; then
    export PATH="$LOCAL_GC/bin:$PATH"
    export COB_CONFIG_DIR="$LOCAL_GC/config"
    COBC="$LOCAL_GC/bin/cobc.exe"
fi
if [ -z "$COBC" ] && [ -x "$LOCAL_GC/bin/cobc" ]; then
    export PATH="$LOCAL_GC/bin:$PATH"
    export COB_CONFIG_DIR="$LOCAL_GC/config"
    COBC="$LOCAL_GC/bin/cobc"
fi
if [ -z "$COBC" ]; then
    COBC="$(command -v cobc || true)"
fi
if [ -z "$COBC" ]; then
    echo "TEST|FAIL|GnuCOBOL cobc was not found" >&2
    exit 127
fi
# Ubuntu's GnuCOBOL package may carry duplicate _FORTIFY_SOURCE
# definitions in COB_CFLAGS, which makes GCC emit a warning for every
# generated C module. Override it with a single definition when the caller
# has not selected flags explicitly.
if [ "$(uname -s 2>/dev/null || echo unknown)" = "Linux" ] && [ -z "${COB_CFLAGS:-}" ]; then
    export COB_CFLAGS="-O2 -finline-functions -D_FORTIFY_SOURCE=2 -Wno-unused -fsigned-char -Wno-pointer-sign"
fi

export BNK_COBC="$COBC"

if [ "${BNK_SKIP_BUILD:-0}" != "1" ]; then
    "$ROOT/scripts/build.sh"
fi

PYTHON="${PYTHON:-}"
if [ -z "$PYTHON" ]; then
    if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' >/dev/null 2>&1; then
        PYTHON="python3"
    elif command -v python >/dev/null 2>&1 && python -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' >/dev/null 2>&1; then
        PYTHON="python"
    else
        echo "TEST|FAIL|Python 3.10 or newer was not found" >&2
        exit 127
    fi
fi

exec "$PYTHON" "$ROOT/tests/run_tests.py" "$@"
