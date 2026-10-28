#!/usr/bin/env bash
set -euo pipefail

# Official distribution URLs/layout, verified against the official installer.
# Match the project's declared and previously validated compiler. Updating the
# release is an explicit compatibility change, not a floating CI side effect.
release='0.10.12%2B1634b282e'
sdk_sha=9bbda7d342fa39654a65c23805e5ff5a3915a26b36627a2565a6b1a99d099e01
core_sha=784a12ce4e204a3a98a0b704a021f747b916412efacd4dfe2f4e5c27ae183ac1
: "${RUNNER_TEMP:?GitHub runner temporary directory is required}"
: "${GITHUB_PATH:?GitHub path output is required}"
export MOON_HOME="$RUNNER_TEMP/phylo-moonbit"
stage="$RUNNER_TEMP/phylo-moonbit-download"
mkdir -p "$stage" "$MOON_HOME/lib" ci-evidence
curl --fail --location --silent --show-error \
  "https://cli.moonbitlang.com/binaries/$release/moonbit-linux-x86_64.tar.gz" \
  --output "$stage/sdk.tar.gz"
curl --fail --location --silent --show-error \
  "https://cli.moonbitlang.com/cores/core-$release.tar.gz" \
  --output "$stage/core.tar.gz"
printf '%s  %s\n' "$sdk_sha" "$stage/sdk.tar.gz" "$core_sha" "$stage/core.tar.gz" | sha256sum --check
sha256sum "$stage/sdk.tar.gz" "$stage/core.tar.gz" > ci-evidence/sdk-downloads.sha256
tar -xzf "$stage/sdk.tar.gz" -C "$MOON_HOME"
tar -xzf "$stage/core.tar.gz" -C "$MOON_HOME/lib"
# The official archives store binaries as 0664; match the official installer's
# executable-mode setup before invoking moon, moonc, moonrun or internal tcc.
chmod +x "$MOON_HOME/bin/"* "$MOON_HOME/bin/internal/tcc"
ln -sfn moon "$MOON_HOME/bin/moonx"
export PATH="$MOON_HOME/bin:$PATH"
printf '%s\n' "$MOON_HOME/bin" >> "$GITHUB_PATH"
printf 'MOON_HOME=%s\n' "$MOON_HOME" >> "$GITHUB_ENV"
moon -C "$MOON_HOME/lib/core" bundle --target js --warn-list -a
moon -C "$MOON_HOME/lib/core" bundle --target wasm-gc --warn-list -a
moon version --all | tee ci-evidence/toolchain.txt
