#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENMP_VERSION="${OPENMP_VERSION:-v1.5.8.3079}"
WORK_DIR="${RUNNER_TEMP:-/tmp}/openmp-dm-tdm-${OPENMP_VERSION}"
DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist}"
RELEASE_URL="https://github.com/openmultiplayer/open.mp/releases/download/${OPENMP_VERSION}"

for tool in curl unzip tar find python3; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        echo "Required tool not found: ${tool}" >&2
        exit 1
    fi
done

if [[ ! -s "${ROOT_DIR}/gamemodes/dm_tdm.pwn" || ! -s "${ROOT_DIR}/gamemodes/dm_tdm.amx" ]]; then
    echo "Both dm_tdm.pwn and the compiled dm_tdm.amx must exist before packaging." >&2
    exit 1
fi

rm -rf "${WORK_DIR}" "${DIST_DIR}"
mkdir -p "${WORK_DIR}/downloads" "${WORK_DIR}/windows" "${WORK_DIR}/linux" "${DIST_DIR}"

curl --fail --location --retry 3 --retry-delay 2 \
    "${RELEASE_URL}/open.mp-win-x86.zip" \
    --output "${WORK_DIR}/downloads/open.mp-win-x86.zip"
curl --fail --location --retry 3 --retry-delay 2 \
    "${RELEASE_URL}/open.mp-linux-x86.tar.gz" \
    --output "${WORK_DIR}/downloads/open.mp-linux-x86.tar.gz"

unzip -q "${WORK_DIR}/downloads/open.mp-win-x86.zip" -d "${WORK_DIR}/windows"
tar -xzf "${WORK_DIR}/downloads/open.mp-linux-x86.tar.gz" -C "${WORK_DIR}/linux"

find_server_root() {
    local extracted_root="$1"
    local executable_name="$2"
    local executable_path

    executable_path="$(find "${extracted_root}" -maxdepth 6 -name "${executable_name}" -print -quit)"
    if [[ -z "${executable_path}" ]]; then
        echo "Could not find ${executable_name} in ${extracted_root}" >&2
        find "${extracted_root}" -maxdepth 3 -print >&2
        return 1
    fi

    dirname "${executable_path}"
}

assemble_server() {
    local platform="$1"
    local extracted_root="$2"
    local executable_name="$3"
    local destination="${DIST_DIR}/${platform}"
    local runtime_root

    runtime_root="$(find_server_root "${extracted_root}" "${executable_name}")"
    mkdir -p "${destination}"
    cp -a "${runtime_root}/." "${destination}/"

    # Keep the official open.mp runtime and development includes, but remove
    # sample gamemodes and unused optional content from the distribution.
    rm -rf "${destination}/gamemodes" "${destination}/filterscripts"
    mkdir -p "${destination}/gamemodes" "${destination}/scriptfiles"
    for optional_dir in components filterscripts models plugins; do
        if [[ -d "${destination}/${optional_dir}" ]]; then
            find "${destination}/${optional_dir}" -mindepth 1 -maxdepth 1 \
                -exec rm -rf -- {} +
        else
            mkdir -p "${destination}/${optional_dir}"
        fi
    done
    find "${destination}/scriptfiles" -mindepth 1 -maxdepth 1 \
        -exec rm -rf -- {} +

    rm -f "${destination}/server.cfg" "${destination}/log.txt" \
        "${destination}/server_log.txt" "${destination}/crashinfo.txt"
    cp "${ROOT_DIR}/config.json" "${destination}/config.json"
    cp "${ROOT_DIR}/gamemodes/dm_tdm.pwn" "${destination}/gamemodes/dm_tdm.pwn"
    cp "${ROOT_DIR}/gamemodes/dm_tdm.amx" "${destination}/gamemodes/dm_tdm.amx"
    cp "${ROOT_DIR}/README.md" "${destination}/README-DM-TDM.md"

    cat > "${destination}/README-RU.txt" <<EOF
open.mp DM/TDM — серверный пакет ${OPENMP_VERSION}

Содержимое:
- только наш игровой режим: gamemodes/dm_tdm.pwn и gamemodes/dm_tdm.amx;
- конфигурация config.json;
- официальный сервер open.mp и его стандартные файлы;
- встроенные include-файлы/инструменты Qawno из официального пакета.

Сторонние плагины и компоненты не требуются: режим использует только API open.mp.
Порт сервера: UDP 7777. RCON выключен.

Запуск:
- Windows: запустите start.bat;
- Linux: выполните bash ./start.sh.
EOF

    if [[ "${platform}" == "windows" ]]; then
        cat > "${destination}/start.bat" <<'EOF'
@echo off
cd /d "%~dp0"
omp-server.exe
pause
EOF
    else
        cat > "${destination}/start.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
chmod +x ./omp-server
exec ./omp-server
EOF
        chmod +x "${destination}/start.sh"
    fi

    if [[ ! -f "${destination}/${executable_name}" ]]; then
        echo "Packaged server binary is missing: ${destination}/${executable_name}" >&2
        return 1
    fi
    if [[ ! -f "${destination}/config.json" || ! -f "${destination}/gamemodes/dm_tdm.amx" ]]; then
        echo "Packaged config or gamemode is missing for ${platform}." >&2
        return 1
    fi

    echo "Assembled ${platform} server at ${destination}"
}

assemble_server windows "${WORK_DIR}/windows" omp-server.exe
assemble_server linux "${WORK_DIR}/linux" omp-server

mkdir -p "${DIST_DIR}/release"
python3 - "${DIST_DIR}/windows" "${DIST_DIR}/release/openmp-dm-tdm-windows.zip" <<'PY'
from pathlib import Path
from sys import argv
from zipfile import ZIP_DEFLATED, ZipFile

source = Path(argv[1])
archive_path = Path(argv[2])
with ZipFile(archive_path, "w", ZIP_DEFLATED) as archive:
    for path in sorted(source.rglob("*")):
        if path.is_file():
            archive.write(path, path.relative_to(source).as_posix())
PY

tar -czf "${DIST_DIR}/release/openmp-dm-tdm-linux.tar.gz" \
    -C "${DIST_DIR}/linux" .

echo "Public release assets are ready in ${DIST_DIR}/release"
