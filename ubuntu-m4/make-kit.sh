#!/bin/bash
# Build an Ubuntu M4 installer kit from the Omarchy-M4-Native update.4 kit.
#   make-kit.sh COMPANION_DIR BOOT_DIR UBUNTU_ROOT_EXT4 OUT_DIR
# COMPANION_DIR: extracted update.4 companion tar (Install.command,
#                installer-macos.tar.gz, installer_data.json, notices/)
# BOOT_DIR:      boot/ files from the update.4 OS zip (loader.bin, Image.gz,
#                portable.dtb, initramfs.cpio.gz) - used unchanged
set -euo pipefail
C=$(realpath "$1"); B=$(realpath "$2"); ROOT=$(realpath "$3"); OUT=$4
HERE=$(cd "$(dirname "$0")" && pwd)
PKG=ubuntu-m4-j713-26.04.zip
[ ! -e "$OUT" ] || { echo "$OUT exists" >&2; exit 1; }
mkdir -p "$OUT/os" "$OUT/notices"
# Boot chain must be byte-identical to update.4 (the installer pins these).
(cd "$B" && sha256sum -c - <<'SUMS')
3a3f7a64c65fc366d5ac9aece3e1bee64119be012aa1ec5b15d2743c6f91fce4  loader.bin
c3704cfd2afb7760e73f0b9939a68864a30bd916fcd478bd960e538373123dc9  Image.gz
e54c77a760a5b696486f9d80c7c83ca4295d641113bb9e54d13e259863bf9b07  portable.dtb
0b4e8f8ac58ec7afda6de5810b1f96599f582297e246cbe7ac4dfdfad8e0af28  initramfs.cpio.gz
SUMS
echo "== Writing $PKG (compressing the root image takes a while)"
python3 -I - "$B" "$ROOT" "$OUT/os/$PKG" <<'PY'
import sys, zipfile, os
boot, root, out = sys.argv[1:]
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, allowZip64=True, compresslevel=6) as z:
    for n in ('portable.dtb', 'initramfs.cpio.gz', 'Image.gz', 'loader.bin'):
        z.write(os.path.join(boot, n), 'boot/' + n)
    with open(root, 'rb') as src, z.open('root.ext4', 'w', force_zip64=True) as dst:
        while True:
            b = src.read(8 << 20)
            if not b: break
            dst.write(b)
PY
python3 -I - "$C/installer_data.json" "$OUT/installer_data.json" "$PKG" <<'PY'
import json, sys
src, dst, pkg = sys.argv[1:]
d = json.load(open(src)); o = d['os_list'][0]
o['name'] = 'Ubuntu 26.04 M4 (experimental J713, Omarchy-M4-Native boot chain)'
o['default_os_name'] = 'Ubuntu M4'
o['package'] = pkg
json.dump(d, open(dst, 'w'), indent=2, sort_keys=True); open(dst, 'a').write('\n')
PY
cp "$C/installer-macos.tar.gz" "$OUT/"
cp -a "$C/notices/." "$OUT/notices/"
sed -e 's/Experimental Omarchy M4 Native v0.1.0-alpha.1./Experimental Ubuntu 26.04 for the M4 Air (Omarchy-M4-Native update.4 boot chain)./' \
    -e 's/Read KNOWN-LIMITATIONS.md, including the shutdown problem./Read START-HERE.md, including the known limitations./' \
    -e 's/Protected movies require Google Widevine. It is obtained from Google after Linux starts./Widevine is not used by Ubuntu M4; answer N./' \
    "$C/Install.command" > "$OUT/Install.command"
sed -i '2a # Modified for Ubuntu M4 by the cuddly-parakeet project: message text only.' "$OUT/Install.command"
chmod 755 "$OUT/Install.command"
cp "$HERE/START-HERE.md" "$OUT/START-HERE.md"
(cd "$OUT" && find . -type f ! -name SHA256SUMS | sed 's#^\./##' | sort | xargs -d '\n' sha256sum > SHA256SUMS)
ls -la "$OUT" "$OUT/os"
