#!/bin/bash
# Build the Ubuntu M4 installer kit end to end.
#   sudo ./build.sh [WORK_DIR]
# Needs: Ubuntu/Debian host (arm64 is fastest; x86_64 works via qemu-user),
# root, ~35 GB free, internet. Output: WORK_DIR/kit (copy it to macOS).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
W=$(realpath -m "${1:-$HERE/work}")
REL=https://github.com/Kb2uka/Omarchy-M4-Native/releases/download/v0.1.0-alpha.1-update.4
UUID=4d79437a-27e6-4b2e-a86f-0be326618b45   # rootfs_uuid the update.4 installer expects
[ "$(id -u)" = 0 ] || { echo "Run as root (sudo)." >&2; exit 1; }
mkdir -p "$W"/{dl,companion,om/mnt,ub/mnt}

echo "== Host tools"
apt-get install -y -q mmdebstrap e2fsprogs curl python3 >/dev/null
if [ "$(uname -m)" != aarch64 ]; then
  apt-get install -y -q qemu-user-static binfmt-support >/dev/null
  [ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ] || update-binfmts --enable qemu-aarch64
fi

echo "== Download Omarchy-M4-Native update.4 (verified against its manifest)"
cd "$W/dl"
curl -fsSL -o download-manifest.tsv "$REL/download-manifest.tsv"
# Pin the manifest itself: this hash comes from the release's DOWNLOAD-SHA256SUMS.
echo "c305724ee8e473fc2191f0560da15d04b6e16d665efb8e84f947a94f84eb0d00  download-manifest.tsv" | sha256sum -c -
awk -F'\t' '$1=="companion"{print $2"\t"$4} $1=="part"{print $3"\t"$5}' download-manifest.tsv |
while IFS=$'\t' read -r name sha; do
  if ! echo "$sha  $name" | sha256sum -c --quiet - 2>/dev/null; then
    for i in 1 2 3 4 5; do curl -fL --retry 5 -C - -o "$name" "$REL/$name" && break; sleep $((2**i)); done
    echo "$sha  $name" | sha256sum -c -
  fi
done
zipsha=$(awk -F'\t' '$1=="archive"{print $4}' download-manifest.tsv)
cat *-os.part00? > os.zip && echo "$zipsha  os.zip" | sha256sum -c - && rm -f *-os.part00?
tar -xf *-companion.tar -C "$W/companion" Install.command installer-macos.tar.gz installer_data.json notices

echo "== Extract Omarchy root (sparse) and boot files"
python3 -I - os.zip "$W/om" <<'PY'
import zipfile, sys, os
z = zipfile.ZipFile(sys.argv[1]); out = sys.argv[2]
os.makedirs(out + '/boot', exist_ok=True)
for n in ('boot/portable.dtb', 'boot/initramfs.cpio.gz', 'boot/Image.gz', 'boot/loader.bin'):
    open(os.path.join(out, n), 'wb').write(z.read(n))
zero = bytes(1 << 20)
with z.open('root.ext4') as s, open(out + '/root.ext4', 'wb') as d:
    while (b := s.read(1 << 20)):
        d.seek(len(b), 1) if b == zero[:len(b)] else d.write(b)
    d.truncate()
PY
echo "995b5c2a3a331007056a529e51bf8e805c6c3827abf624efb8e6b8f16788665a  $W/om/root.ext4" | sha256sum -c -
rm -f os.zip

echo "== Bootstrap Ubuntu 26.04 + GNOME into a new root image"
truncate -s 17179869184 "$W/ub/root.ext4"
mkfs.ext4 -q -L ubuntu-m4 -U "$UUID" "$W/ub/root.ext4"
mount -o loop "$W/ub/root.ext4" "$W/ub/mnt"
mount -o loop,ro,noload "$W/om/root.ext4" "$W/om/mnt"
trap 'umount "$W/om/mnt" "$W/ub/mnt" 2>/dev/null || true' EXIT
"$HERE/bootstrap.sh" "$W/ub/mnt"

echo "== Port the M4 layer"
"$HERE/port-m4-layer.sh" "$W/om/mnt" "$W/ub/mnt" "$UUID"
umount "$W/ub/mnt" "$W/om/mnt"; trap - EXIT
e2fsck -fy "$W/ub/root.ext4" >/dev/null || [ $? -le 1 ]

echo "== Make the installer kit"
"$HERE/make-kit.sh" "$W/companion" "$W/om/boot" "$W/ub/root.ext4" "$W/kit"
echo "Kit ready: $W/kit  (copy the whole folder to an exFAT USB drive or to macOS)"
