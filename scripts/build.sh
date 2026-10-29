#!/usr/bin/env bash
# Compile every production COBOL program into build/bin.
set -euo pipefail
set -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="$ROOT/build"
BIN_DIR="$BUILD_DIR/bin"
LOG_DIR="$BUILD_DIR/logs"
COPY_DIR="$ROOT/src/main/cobol/copy"
COMPILE_LOG="$LOG_DIR/compile.log"

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
    echo "BUILD|FAIL|GnuCOBOL cobc was not found" >&2
    echo "Install GnuCOBOL or set COBC to the compiler path." >&2
    exit 127
fi

# Ubuntu's GnuCOBOL package may carry duplicate _FORTIFY_SOURCE
# definitions in COB_CFLAGS, which makes GCC emit a warning for every
# generated C module. Override it with a single definition when the caller
# has not selected flags explicitly.
if [ "$(uname -s 2>/dev/null || echo unknown)" = "Linux" ] && [ -z "${COB_CFLAGS:-}" ]; then
    export COB_CFLAGS="-O2 -finline-functions -D_FORTIFY_SOURCE=2 -Wno-unused -fsigned-char -Wno-pointer-sign"
fi

mkdir -p "$BIN_DIR" "$LOG_DIR"
rm -f "$BIN_DIR/bnkapp" "$BIN_DIR/bnkapp.exe" "$COMPILE_LOG"

CASE_SYSTEM="$(uname -s 2>/dev/null || echo unknown)"
case "$CASE_SYSTEM" in
    MINGW*|MSYS*|CYGWIN*) BIN="$BIN_DIR/bnkapp.exe" ;;
    *) BIN="$BIN_DIR/bnkapp" ;;
esac

COBC_FLAGS=(-std=default -free -O2 -Wall -Wextra -I "$COPY_DIR")
SOURCES=(
    "$ROOT/src/main/cobol/BNKMAIN.CBL"
    "$ROOT/src/main/cobol/BNKVALID.CBL"
    "$ROOT/src/main/cobol/BNKPROC.CBL"
    "$ROOT/src/main/cobol/BNKSETTL.CBL"
    "$ROOT/src/main/cobol/BNKRPT.CBL"
)

{
    echo "COBOL Enterprise Banking build"
    echo "compiler: $COBC"
    "$COBC" --version | head -n 1
    echo "flags: ${COBC_FLAGS[*]}"
    echo "sources: ${SOURCES[*]}"
} | tee "$COMPILE_LOG"

if ! "$COBC" "${COBC_FLAGS[@]}" -x -o "$BIN" "${SOURCES[@]}" 2>&1 | tee -a "$COMPILE_LOG"; then
    echo "BUILD|FAIL|compiler exited nonzero; see $COMPILE_LOG" >&2
    exit 1
fi
if grep -Eiq 'warning:' "$COMPILE_LOG"; then
    echo "BUILD|FAIL|compiler warnings detected; see $COMPILE_LOG" >&2
    exit 1
fi
if [ ! -x "$BIN" ] && [ ! -f "$BIN" ]; then
    echo "BUILD|FAIL|expected binary not produced: $BIN" >&2
    exit 1
fi

echo "BUILD|OK|$BIN"
echo "BUILD_LOG|$COMPILE_LOG"
