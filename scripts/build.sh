#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_FILE="${ROOT_DIR}/gamemodes/dm_tdm.pwn"
OUTPUT_FILE="${ROOT_DIR}/gamemodes/dm_tdm.amx"
PAWNCC_BIN="${PAWNCC:-pawncc}"
OMP_INCLUDE_DIR="${OMP_INCLUDE_DIR:-${ROOT_DIR}/qawno/include}"

if ! command -v "${PAWNCC_BIN}" >/dev/null 2>&1 && [[ ! -x "${PAWNCC_BIN}" ]]; then
    echo "Pawn compiler not found: ${PAWNCC_BIN}" >&2
    echo "Set PAWNCC to the pawncc executable or add pawncc to PATH." >&2
    exit 1
fi

if [[ ! -f "${OMP_INCLUDE_DIR}/open.mp.inc" ]]; then
    echo "open.mp includes not found in: ${OMP_INCLUDE_DIR}" >&2
    echo "Set OMP_INCLUDE_DIR to a directory containing open.mp.inc." >&2
    exit 1
fi

mkdir -p "$(dirname "${OUTPUT_FILE}")"
"${PAWNCC_BIN}" "${SOURCE_FILE}" "-i${OMP_INCLUDE_DIR}" "-o${OUTPUT_FILE}" -O2 -d0 -t4

test -s "${OUTPUT_FILE}"
echo "Build successful: ${OUTPUT_FILE}"
