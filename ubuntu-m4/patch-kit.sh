#!/bin/bash
# Apply the current overlay/ (and START-HERE.md) to an already-built kit,
# without rebuilding Ubuntu. Run as root on Linux (or via build-in-docker.sh
# --patch-kit). Usage: patch-kit.sh KIT_DIR [SCRATCH_DIR]
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
KIT=$(realpath "$1"); W=$(realpath -m "${2:-/tmp/ubuntu-m4-patch}")
PKG=ubuntu-m4-j713-26.04.zip
[ -f "$KIT/os/$PKG" ] || { echo "No $PKG in $KIT/os" >&2; exit 1; }
(cd "$KIT" && sha256sum --quiet -c SHA256SUMS) || { echo "Kit checksums fail; rebuild instead." >&2; exit 1; }
rm -rf "$W"; mkdir -p "$W/boot" "$W/mnt"
echo "== Extracting root image"
python3 -I - "$KIT/os/$PKG" "$W" <<'PY'
import zipfile, sys
z = zipfile.ZipFile(sys.argv[1]); w = sys.argv[2]
for n in ('boot/portable.dtb', 'boot/initramfs.cpio.gz', 'boot/Image.gz', 'boot/loader.bin'):
    open(w + '/' + n, 'wb').write(z.read(n))
zero = bytes(1 << 20)
with z.open('root.ext4') as s, open(w + '/root.ext4', 'wb') as d:
    while (b := s.read(1 << 20)):
        d.seek(len(b), 1) if b == zero[:len(b)] else d.write(b)
    d.truncate()
PY
echo "== Applying overlay"
mount -o loop "$W/root.ext4" "$W/mnt"
trap 'umount "$W/mnt" 2>/dev/null || true' EXIT
[ "$(cat "$W/mnt/etc/m4-root-id")" = 4d79437a-27e6-4b2e-a86f-0be326618b45 ] || { echo "Not an Ubuntu M4 root" >&2; exit 1; }
# Superseded by the session environment generator:
rm -rf "$W/mnt/etc/systemd/user/org.gnome.Shell@.service.d" "$W/mnt/etc/systemd/user/org.gnome.Shell@wayland.service.d"
cp -a "$HERE/overlay/." "$W/mnt/"
umount "$W/mnt"; trap - EXIT
e2fsck -fy "$W/root.ext4" >/dev/null || [ $? -le 1 ]
echo "== Rewriting $PKG"
python3 -I - "$W/boot" "$W/root.ext4" "$W/$PKG" <<'PY'
import sys, zipfile, os
boot, root, out = sys.argv[1:]
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, allowZip64=True, compresslevel=6) as z:
    for n in ('portable.dtb', 'initramfs.cpio.gz', 'Image.gz', 'loader.bin'):
        z.write(os.path.join(boot, n), 'boot/' + n)
    with open(root, 'rb') as src, z.open('root.ext4', 'w', force_zip64=True) as dst:
        while (b := src.read(8 << 20)):
            dst.write(b)
PY
mv "$W/$PKG" "$KIT/os/$PKG"
cp "$HERE/START-HERE.md" "$KIT/START-HERE.md"
(cd "$KIT" && find . -type f ! -name SHA256SUMS | sed 's#^\./##' | sort | xargs -d '\n' sha256sum > SHA256SUMS)
rm -rf "$W"
echo "Kit patched: $KIT"
