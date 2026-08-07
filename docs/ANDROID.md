# Building steamguard-cli for Termux (Android)

## **This method hasnt been tested, yet.**

This produces a native `steamguard` binary you run inside the Termux terminal
app. This is NOT a Play Store or GUI apk — only the CLI binary running in a real terminal (Termux). 

## Why this works

- Networking (`reqwest` 0.12.28) uses `rustls-tls`, not OpenSSL, so there's
  no OpenSSL cross-compile step.
- The TLS crypto backend is `ring` 0.17.14, which is plain C (no C++), so no
  `libc++_shared.so` needs to be bundled alongside the binary.
- All the account-crypto (`aes`, `cbc`, `argon2`, `pbkdf2`, `rsa`, `sha1`) is
  pure Rust — nothing else to cross-compile.
- Random number generation (`getrandom` 0.2.17) uses the Android `getrandom()`
  syscall directly, no extra feature flags needed.
- There are no desktop-only OS calls in the app code (`src/main.rs` only
  calls `std::process::exit`).

## What has to change

The `keyring` feature (`src/encryption/keyring.rs`) depends on Secret
Service / Keychain / Credential Manager equivalents that don't exist for a
headless Termux process. It's already feature-gated in `Cargo.toml` (see the
`[features]` block, `keyring = ["dep:keyring"]`), so you don't edit any code
— you just build without it. The app already knows how to fall back to
prompting for your encryption passphrase directly when the keyring feature
is compiled out (see `src/main.rs`, the `#[cfg(feature = "keyring")]` blocks
around lines 154 and 186).

## One-time setup (on your build machine, not on the phone)

```bash
# 1. Install the Android NDK (r25c or later recommended).
#    Easiest path: install Android Studio, then SDK Manager -> SDK Tools -> NDK.
#    Or download standalone from https://developer.android.com/ndk/downloads

# 2. Add the Rust targets you need. aarch64 covers the overwhelming
#    majority of real Android phones.
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android

# 3. Install cargo-ndk — it configures the linker/sysroot for you so you
#    don't have to hand-write .cargo/config.toml entries.
cargo install cargo-ndk

# 4. Point at your NDK install.
export ANDROID_NDK_HOME=/path/to/Android/Sdk/ndk/<version>
```

## Build

```bash
./scripts/build-android.sh
```

This builds without the `keyring` feature and without `updater`'s desktop
notifier assumptions being an issue (updater just checks GitHub releases
over HTTPS, no OS-specific behavior). Output binaries land in
`./dist-android/<target>/steamguard`.

## Getting the binary onto the phone

Termux's app storage is sandboxed — `adb push` can't write directly into
Termux's home directory unless the device is rooted. Go through shared
storage instead:

```bash
adb push dist-android/aarch64-linux-android/steamguard /sdcard/Download/
```

Then, inside Termux itself:

```bash
termux-setup-storage   # one-time, grants Termux access to /sdcard
cp /storage/downloads/steamguard $PREFIX/bin/steamguard
chmod +x $PREFIX/bin/steamguard
steamguard --help
```

## Known limitations

- `keyring` feature must stay off — you'll be prompted for your encryption
  passphrase each session instead of it being cached by the OS. This is a
  real (if less convenient) security model, not a broken one.
- Genuine Android Keystore integration (via the separate Termux:API app's
  `termux-keystore` command) is possible in principle but is a real crypto
  design task — it's a signing primitive, not a drop-in secret store — and
  is deliberately not included here. Worth doing as a follow-up, not a
  first cut.
- QR code login flow (`qr` feature, uses `rqrr`/`image`) should work fine
  since both are pure Rust, but hasn't been tested on-device here.