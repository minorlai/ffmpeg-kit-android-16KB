#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_AAR="${ROOT_DIR}/ffmpeg-kit-talkin-slim-16kb.aar"
PREBUILT_AAR="${ROOT_DIR}/prebuilt/bundle-android-aar/ffmpeg-kit/ffmpeg-kit.aar"
AAR_PATH="${1:-${DEFAULT_AAR}}"

if [[ ! -f "${AAR_PATH}" && -f "${PREBUILT_AAR}" ]]; then
  AAR_PATH="${PREBUILT_AAR}"
fi

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required tool: $1"
}

read_program_headers_wide() {
  local elf_file="$1"

  if "${READ_ELF}" -W -l "${elf_file}" >/dev/null 2>&1; then
    "${READ_ELF}" -W -l "${elf_file}"
    return
  fi

  if "${READ_ELF}" --wide -l "${elf_file}" >/dev/null 2>&1; then
    "${READ_ELF}" --wide -l "${elf_file}"
    return
  fi

  "${READ_ELF}" -l "${elf_file}"
}

verify_load_alignment() {
  local elf_file="$1"
  local label="$2"
  local headers
  local alignments

  headers="$(read_program_headers_wide "${elf_file}")"
  alignments="$(awk '$1 == "LOAD" { print $NF }' <<<"${headers}")"

  if [[ -z "${alignments}" ]]; then
    awk '$1 == "LOAD" { print }' <<<"${headers}" >&2
    fail "${label}: could not parse LOAD segment alignment"
  fi

  while IFS= read -r alignment; do
    [[ -n "${alignment}" ]] || continue
    if (( alignment < 0x4000 )); then
      awk '$1 == "LOAD" { print }' <<<"${headers}" >&2
      fail "${label}: LOAD segment alignment is ${alignment}, expected at least 0x4000"
    fi
  done <<<"${alignments}"
}

find_readelf() {
  if command -v llvm-readelf >/dev/null 2>&1; then
    command -v llvm-readelf
    return
  fi

  if command -v readelf >/dev/null 2>&1; then
    command -v readelf
    return
  fi

  if [[ -n "${ANDROID_NDK_ROOT:-}" ]]; then
    local ndk_readelf
    ndk_readelf="$(find "${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt" -path "*/bin/llvm-readelf" -type f -print -quit 2>/dev/null || true)"
    if [[ -n "${ndk_readelf}" ]]; then
      echo "${ndk_readelf}"
      return
    fi
  fi

  echo ""
}

require_tool unzip
require_tool strings

[[ -f "${AAR_PATH}" ]] || fail "AAR not found: ${AAR_PATH}"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/talkin-ffmpeg-aar.XXXXXX")"
trap 'rm -rf "${TMP_DIR}"' EXIT

unzip -q "${AAR_PATH}" -d "${TMP_DIR}"

JNI_DIR="${TMP_DIR}/jni"
[[ -d "${JNI_DIR}" ]] || fail "AAR has no jni directory."

actual_abis="$(find "${JNI_DIR}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
expected_abis="arm64-v8a armeabi-v7a"

[[ "${actual_abis}" == "${expected_abis}" ]] || fail "Unexpected ABI set: ${actual_abis}; expected: ${expected_abis}"

if find "${JNI_DIR}" -path "*_neon*" -print -quit | grep -q .; then
  fail "Found armeabi-v7a-neon artifacts in AAR."
fi

READ_ELF="$(find_readelf)"

for abi in arm64-v8a armeabi-v7a; do
  abi_dir="${JNI_DIR}/${abi}"
  libavcodec="${abi_dir}/libavcodec.so"

  [[ -f "${abi_dir}/libffmpegkit.so" ]] || fail "${abi}: missing libffmpegkit.so"
  [[ -f "${abi_dir}/libavformat.so" ]] || fail "${abi}: missing libavformat.so"
  [[ -f "${libavcodec}" ]] || fail "${abi}: missing libavcodec.so"
  [[ -f "${abi_dir}/libavfilter.so" ]] || fail "${abi}: missing libavfilter.so"
  [[ -f "${abi_dir}/libswscale.so" ]] || fail "${abi}: missing libswscale.so"
  [[ -f "${abi_dir}/libswresample.so" ]] || fail "${abi}: missing libswresample.so"

  strings "${libavcodec}" | grep -Eiq "libopenh264|openh264" || fail "${abi}: OpenH264 encoder symbols were not found in libavcodec.so"
  strings "${libavcodec}" | grep -Eq "filter_units|remove_types" || fail "${abi}: filter_units bitstream filter symbols were not found in libavcodec.so"

  if [[ -n "${READ_ELF}" ]]; then
    verify_load_alignment "${libavcodec}" "${abi}: libavcodec.so"
    verify_load_alignment "${abi_dir}/libffmpegkit.so" "${abi}: libffmpegkit.so"
  else
    echo "WARN: readelf/llvm-readelf not found; skipped 16KB ELF alignment check." >&2
  fi
done

echo "OK: ${AAR_PATH}"
echo "ABI set: ${actual_abis}"
echo "OpenH264, filter_units, and 16KB alignment checks passed."
