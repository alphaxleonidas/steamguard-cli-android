#!/usr/bin/env bash
set -euo pipefail

# Cross-compiles steamguard-cli for Termux (Android).
# See docs/ANDROID.md for one-time setup (NDK, rustup targets, cargo-ndk).

if ! command -v cargo-ndk >/dev/null 2>&1; then
	echo "cargo-ndk not found. Install it with: cargo install cargo-ndk" >&2
	exit 1
fi

if [ -z "${ANDROID_NDK_HOME:-}" ]; then
	echo "ANDROID_NDK_HOME is not set. Point it at your Android NDK install." >&2
	exit 1
fi

# aarch64 covers the large majority of real devices. Add/remove targets
# as needed; armv7 covers older 32-bit phones, x86_64 covers emulators.
TARGETS=(aarch64-linux-android armv7-linux-androideabi x86_64-linux-android)

# Termux's current minimum supported Android version.
API_LEVEL=24

OUT_DIR=./dist-android

cargo ndk \
	--target "${TARGETS[0]}" --target "${TARGETS[1]}" --target "${TARGETS[2]}" \
	--platform "${API_LEVEL}" \
	--output-dir "${OUT_DIR}" \
	build --release \
	--no-default-features --features qr,updater

echo ""
echo "Done. Binaries:"
for t in "${TARGETS[@]}"; do
	echo "  ${OUT_DIR}/${t}/steamguard"
done
echo ""
echo "To install on-device: adb push ${OUT_DIR}/aarch64-linux-android/steamguard /sdcard/Download/"
echo "Then in Termux: cp /sdcard/Download/steamguard \$PREFIX/bin/ && chmod +x \$PREFIX/bin/steamguard"
