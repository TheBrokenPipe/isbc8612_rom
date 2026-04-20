#!/usr/bin/env bash
set -euo pipefail
trap 'echo "BUILD FAILED" >&2' ERR

ROOT="$(cd "$(dirname "$0")" && pwd)"

SRC="$ROOT/src"

TOOLS_ROOT="$ROOT/tools"
THAMES_ROOT="$TOOLS_ROOT/thames"
THAMES="$THAMES_ROOT/bin/thames"

ISIS_ROOT="$ROOT/isis"
F0="$ISIS_ROOT/f0"
F1="$ISIS_ROOT/f1"
F2="$ISIS_ROOT/f2"
F3="$ISIS_ROOT/f3"

OUTPUT="$ROOT/output"
BIN="$OUTPUT/bin"
OBJ="$OUTPUT/obj"

# Build thames if needed.
if [ ! -x "$THAMES" ]; then
    (cd "$THAMES_ROOT" && sh ./configure && make -j4)
fi

# Remove all previous build outputs.
rm -rf "$ISIS_ROOT" "$OUTPUT"

# Create virtual ISIS drives.
mkdir -p "$F0" "$F1" "$F2" "$F3"

# Copy 8086 utilities to F0.
for f in "$TOOLS_ROOT"/utils/*; do
    b="$(basename "$f")"
    lower="$(printf '%s' "$b" | tr 'A-Z' 'a-z')"
    cp "$f" "$F0/$lower"
done

# Copy monitor source code to F1.
cp "$SRC/SBCMON.PLM" "$F1/sbcmon.plm"

# Copy the compiler to F2.
for f in "$TOOLS_ROOT"/plm86/*; do
    b="$(basename "$f")"
    cp "$f" "$F2/$(printf '%s' "$b" | tr 'A-Z' 'a-z')"
done

# Export ISIS drive paths.
export ISIS_F0="$F0"
export ISIS_F1="$F1"
export ISIS_F2="$F2"
export ISIS_F3="$F3"

# Build the monitor.
echo 'PAGEWIDTH(95)' | "$THAMES" :F2:PLM86 :F1:SBCMON.PLM 'LARGE OPTIMIZE(2)' 'PRINT(:F3:SBCMON.LST)' '&'
"$THAMES" :F0:LINK86 :F1:SBCMON.OBJ TO :F1:SBCMON.LNK
echo 'ADDRESSES(SEGMENTS(MONITOR_CODE(0FE800H),MONITOR_DATA(0H),STACK(130H))) BOOTSTRAP' | "$THAMES" :F0:LOC86 :F1:SBCMON.LNK TO :F1:SBCMON '&'
"$THAMES" :F0:OH86 :F1:SBCMON TO :F1:SBCMON.HEX

# Build succeeded, save output and clean up ISIS directory.
mkdir -p "$BIN" "$OBJ"
cp "$F1/sbcmon.obj" "$OBJ/SBCMON.OBJ"
cp "$F1/sbcmon.obj" "$OBJ/SBCMON.OBJ"
cp "$F1/sbcmon.lnk" "$OBJ/SBCMON.LNK"
cp "$F1/sbcmon.mp1" "$OBJ/SBCMON.MP1"
cp "$F1/sbcmon" "$OBJ/SBCMON"
cp "$F1/sbcmon.mp2" "$OBJ/SBCMON.MP2"
cp "$F1/sbcmon.hex" "$OBJ/SBCMON.HEX"
cp "$F3/sbcmon.lst" "$OBJ/SBCMON.LST"
rm -rf "$ISIS_ROOT"

# Generate ROM binary.
python3 "$TOOLS_ROOT/hex2rom.py" "$OBJ/SBCMON.HEX" "$BIN/SBCMON.BIN"
