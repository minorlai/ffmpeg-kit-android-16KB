# TalkIn Slim Android FFmpegKit

This fork keeps a small 16KB-page-size Android FFmpegKit build for TalkIn video compression.

## Target

- Keep only `arm64-v8a` and `armeabi-v7a`.
- Disable `armeabi-v7a-neon`, `x86`, and `x86_64`.
- Keep the 16KB page-size linker flag already present in this fork.
- Enable `openh264` so FFmpeg can encode browser-playable H.264 without GPL `x264`.
- Do not enable `libiconv`; this slim build does not need FFmpeg iconv support for MP4/H.264/AAC compression.
- Keep native FFmpeg filters/bitstream filters, including `filter_units`, for HEVC Dolby Vision RPU cleanup fallback.

## Build

```bash
export ANDROID_SDK_ROOT=/path/to/android/sdk
export ANDROID_NDK_ROOT=/path/to/android/ndk

./scripts/build-talkin-slim-android.sh --force
```

If your local NDK 27+ installation does not contain the legacy `platforms/android-*`
directories required by this ffmpeg-kit build script, use NDK 21:

```bash
export ANDROID_SDK_ROOT=/Users/allen/Develop/Android/AS_SDK
export ANDROID_NDK_ROOT=/Users/allen/Develop/Android/AS_SDK/ndk/21.4.7075529

bash scripts/build-talkin-slim-android.sh --force
```

The script writes the normal FFmpegKit output to:

```text
prebuilt/bundle-android-aar/ffmpeg-kit/ffmpeg-kit.aar
```

It also copies it to a stable TalkIn artifact name:

```text
ffmpeg-kit-talkin-slim-16kb.aar
```

## Verify

```bash
./scripts/verify-talkin-slim-aar.sh
```

The verifier checks:

- AAR contains only `arm64-v8a` and `armeabi-v7a`.
- No `_neon`, `x86`, or `x86_64` ABI artifacts are packaged.
- `libavcodec.so` contains OpenH264 encoder symbols.
- `libavcodec.so` contains `filter_units`/`remove_types` symbols.
- `libavcodec.so` and `libffmpegkit.so` show 16KB `LOAD` alignment when `readelf` is available.

## App-side Command Shape

For browser `<video>` playback, prefer the OpenH264 strategy when `libx264` is not available:

```text
-c:v libopenh264
-b:v <targetBitrate>k
-maxrate <targetBitrate>k
-bufsize <targetBitrate*2>k
-pix_fmt yuv420p
-g <keyframeInterval>
-tag:v avc1
-movflags +faststart
-f mp4
-c:a aac
-profile:a aac_low
-b:a 128k
-ar 44100
-ac 2
```

Do not pass `-preset` or `-crf` to `libopenh264`; those are `libx264` options and will fail with this slim LGPL build.

## Maven Central

Coordinate:

```gradle
implementation "io.github.minorlai:ffmpeg-kit-16kb:6.1.2"
```

Artifact page:

```text
https://central.sonatype.com/artifact/io.github.minorlai/ffmpeg-kit-16kb/6.1.2
```

Before publishing, configure these GitHub repository secrets:

```text
MAVEN_CENTRAL_USERNAME
MAVEN_CENTRAL_PASSWORD
SIGNING_IN_MEMORY_KEY
SIGNING_IN_MEMORY_KEY_ID
SIGNING_IN_MEMORY_KEY_PASSWORD
```

Then run the `talkin slim android maven` workflow manually with `publish=true`,
or push tag `v6.1.2`.
