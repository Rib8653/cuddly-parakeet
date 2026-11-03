#!/usr/bin/env bash
# Build an experimental Asahi kernel + M4 MacBook Air device trees.
# Usage: kernel/build.sh [path-to-linux-tree]   (clones it if missing)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=${1:-$HERE/linux}
BRANCH=${ASAHI_BRANCH:-asahi-soc/for-next}
OUT=$HERE/out
if [ ! -d "$SRC/.git" ]; then
  git clone --depth 1 -b "$BRANCH" https://github.com/AsahiLinux/linux.git "$SRC"
fi
export ARCH=arm64 LLVM=1
make -C "$SRC" O="$OUT/build" defconfig
"$SRC/scripts/kconfig/merge_config.sh" -m -O "$OUT/build" "$OUT/build/.config" "$HERE/m4-air.config"
make -C "$SRC" O="$OUT/build" olddefconfig
# Report fragment options that didn't survive (missing driver / wrong name)
grep -E '^CONFIG_[A-Z0-9_]+=' "$HERE/m4-air.config" | while IFS= read -r line; do
  grep -qxF "$line" "$OUT/build/.config" || echo "NOTE: not applied: $line"
done
make -C "$SRC" O="$OUT/build" -j"$(nproc)" Image.gz \
  apple/t8132-j713.dtb apple/t8132-j715.dtb
mkdir -p "$OUT/dist"
cp "$OUT/build/arch/arm64/boot/Image.gz" "$OUT/build/arch/arm64/boot/Image" "$OUT/dist/"
cp "$OUT/build/arch/arm64/boot/dts/apple/"t8132-j71[35].dtb "$OUT/dist/"
cp "$OUT/build/.config" "$OUT/dist/config"
git -C "$SRC" log -1 --format='kernel: %H %s' > "$OUT/dist/SOURCE"
ls -la "$OUT/dist"
