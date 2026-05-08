#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

print_build_log_on_error() {
  local exit_code=$?
  if [[ ${exit_code} -ne 0 && -f "${ROOT_DIR}/build.log" ]]; then
    echo
    echo "----- build.log tail -----" >&2
    tail -300 "${ROOT_DIR}/build.log" >&2
    echo "----- end build.log tail -----" >&2
  fi
  exit "${exit_code}"
}

trap print_build_log_on_error EXIT

if [[ -z "${ANDROID_SDK_ROOT:-}" ]]; then
  echo "ANDROID_SDK_ROOT is not defined." >&2
  exit 1
fi

if [[ -z "${ANDROID_NDK_ROOT:-}" ]]; then
  echo "ANDROID_NDK_ROOT is not defined." >&2
  exit 1
fi

./android.sh \
  --api-level=24 \
  --disable-x86 \
  --disable-x86-64 \
  --disable-arm-v7a-neon \
  --enable-openh264 \
  "$@"

AAR_PATH="${ROOT_DIR}/prebuilt/bundle-android-aar/ffmpeg-kit/ffmpeg-kit.aar"
DIST_PATH="${ROOT_DIR}/ffmpeg-kit-talkin-slim-16kb.aar"

if [[ ! -f "${AAR_PATH}" ]]; then
  echo "Expected AAR not found: ${AAR_PATH}" >&2
  exit 1
fi

cp "${AAR_PATH}" "${DIST_PATH}"

echo
echo "TalkIn slim AAR created:"
echo "${DIST_PATH}"
echo
echo "Run ./scripts/verify-talkin-slim-aar.sh to verify ABI, OpenH264, filter_units, and 16KB ELF alignment."
