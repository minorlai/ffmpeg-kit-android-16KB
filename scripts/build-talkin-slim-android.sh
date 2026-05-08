#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

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
  --enable-libiconv \
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
