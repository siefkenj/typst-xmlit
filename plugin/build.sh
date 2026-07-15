#!/usr/bin/env bash
# Build the typst-relaxng plugin and install it into the Typst package.
#
# Size pipeline (measured; see plugin/README.md):
#   baseline (opt-level="s")                        3.01 MB
#   + release profile: opt-level="z", fat LTO,
#     codegen-units=1, strip, panic="abort"         1.58 MB
#   + nightly -Cpanic=immediate-abort + build-std   1.36 MB   (optional)
#   + wasm-opt -Oz                                  1.24 MB
#   + regex-shim (regex-lite via [patch])           0.60 MB
#
# Uses nightly + build-std when available, falling back to stable.
set -euo pipefail
# Rustup-managed toolchains may not be on PATH in non-login shells.
if [ -f "$HOME/.cargo/env" ]; then . "$HOME/.cargo/env"; fi
cd "$(dirname "$0")/typst-relaxng"

TARGET=wasm32-unknown-unknown
OUT=target/$TARGET/release/typst_relaxng.wasm
DEST=../../src/relaxng/relaxng.wasm

if rustup toolchain list 2>/dev/null | grep -q nightly && \
   rustup component list --toolchain nightly --installed 2>/dev/null | grep -q rust-src; then
  echo "building with nightly (panic=immediate-abort, build-std)"
  RUSTFLAGS="-Zunstable-options -Cpanic=immediate-abort" \
    cargo +nightly build --release --target $TARGET -Z build-std=std,panic_abort
else
  echo "building with stable (install nightly + rust-src for a smaller binary)"
  cargo build --release --target $TARGET
fi

if command -v wasm-opt >/dev/null; then
  echo "shrinking with wasm-opt -Oz"
  wasm-opt -Oz \
    --enable-bulk-memory --enable-sign-ext \
    --enable-nontrapping-float-to-int --enable-mutable-globals \
    "$OUT" -o "$DEST"
else
  echo "wasm-opt not found (apt install binaryen); installing unoptimized"
  cp "$OUT" "$DEST"
fi

ls -la "$DEST"
