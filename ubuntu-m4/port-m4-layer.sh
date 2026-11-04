#!/bin/bash
# Apply the Omarchy-M4-Native M4 layer and Ubuntu M4 settings to an Ubuntu
# arm64 root filesystem.
#   port-m4-layer.sh OMARCHY_ROOT UBUNTU_ROOT FS_UUID
# OMARCHY_ROOT: mounted (read-only) Omarchy-M4-Native update.4 root.ext4
# UBUNTU_ROOT:  mounted Ubuntu 26.04 arm64 root (from bootstrap.sh)
set -euo pipefail
OM=$(realpath "$1"); UB=$(realpath "$2"); UUID=$3
HERE=$(cd "$(dirname "$0")" && pwd)
KREL=7.1.9-m4-gpu-backport-20261008
[ -d "$OM/usr/lib/modules/$KREL" ] || { echo "Not the expected Omarchy root" >&2; exit 1; }
[ -x "$UB/usr/lib/systemd/systemd" ] || { echo "Not an Ubuntu root" >&2; exit 1; }

echo "== Copying M4 layer (byte-for-byte)"
grep -v '^#' "$HERE/m4-files.txt" | sed '/^$/d' | while IFS= read -r p; do
  (cd "$OM" && cp -a --parents "${p%/}" "$UB/")
done
echo "== Verifying copies"
grep -v '^#' "$HERE/m4-files.txt" | sed '/^$/d' | while IFS= read -r p; do
  (cd "$OM" && find "${p%/}" -type f -print0 | xargs -0 sha256sum) > /tmp/m4-sums.$$
  (cd "$UB" && sha256sum --quiet -c /tmp/m4-sums.$$) || { echo "MISMATCH in $p" >&2; exit 1; }
done
rm -f /tmp/m4-sums.$$

echo "== Ubuntu M4 overlay"
cp -a "$HERE/overlay/." "$UB/"
printf '%s\n' "$UUID" > "$UB/etc/m4-root-id"
printf '127.0.0.1\tlocalhost\n127.0.1.1\tubuntu-m4-air\n::1\tlocalhost ip6-localhost ip6-loopback\n' > "$UB/etc/hosts"
: > "$UB/etc/fstab"   # the M4 initramfs writes the real fstab on first boot

# The M4 start scripts use PATH=/usr/bin:/bin; make sure kmod tools are there.
for t in insmod modprobe rmmod lsmod depmod modinfo; do
  if [ ! -e "$UB/usr/bin/$t" ] && [ -e "$UB/usr/sbin/$t" ]; then ln -s ../sbin/$t "$UB/usr/bin/$t"; fi
done

echo "== Configuring inside the image"
cp /etc/resolv.conf "$UB/etc/resolv.conf.m4build" 2>/dev/null || true
for d in dev proc sys; do mount --bind /$d "$UB/$d"; done
trap 'for d in sys proc dev; do umount -l "$UB/$d" 2>/dev/null || true; done' EXIT
chroot "$UB" /bin/bash -euo pipefail <<'CHROOT'
export DEBIAN_FRONTEND=noninteractive LC_ALL=C
mv /etc/resolv.conf /etc/resolv.conf.orig 2>/dev/null || true
cp /etc/resolv.conf.m4build /etc/resolv.conf 2>/dev/null || true
apt-get update -q
# GNOME Web is a normal .deb in Ubuntu's archive (Ubuntu's Firefox is a snap,
# and snapd is blocked), so there is always a browser.
apt-get install -y -q --no-install-recommends mesa-utils wireless-regdb epiphany-browser
# Firefox as a .deb from Mozilla's APT repository, when reachable.
install -d -m 0755 /etc/apt/keyrings
if curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg -o /etc/apt/keyrings/packages.mozilla.org.asc; then
  echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" > /etc/apt/sources.list.d/mozilla.list
  printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' > /etc/apt/preferences.d/mozilla
  apt-get update -q && apt-get install -y -q --no-install-recommends firefox || {
    echo "WARNING: Firefox not installed; GNOME Web is available" >&2
    rm -f /etc/apt/sources.list.d/mozilla.list /etc/apt/preferences.d/mozilla; apt-get update -q; }
else
  echo "WARNING: packages.mozilla.org unreachable; skipping Firefox (GNOME Web is installed)" >&2
  rm -f /etc/apt/keyrings/packages.mozilla.org.asc
fi
# Crash-kernel tooling expects an Ubuntu kernel and bootloader; neither exists here.
apt-get purge -y -q kdump-tools kexec-tools 2>/dev/null || true
# Cloud provisioning would probe for a datasource at every boot.
apt-get purge -y -q cloud-init cloud-init-base 2>/dev/null || true
apt-get autoremove -y -q --purge
apt-get clean
locale-gen en_US.UTF-8 >/dev/null
update-locale LANG=en_US.UTF-8
glib-compile-schemas /usr/share/glib-2.0/schemas
systemctl enable m4-video.service m4-j713-audio-register.service speakersafetyd-j713.service gdm.service NetworkManager.service bluetooth.service
systemctl set-default graphical.target
# No user account: GNOME Initial Setup creates it on first boot.
rm -f /etc/resolv.conf; mv /etc/resolv.conf.orig /etc/resolv.conf 2>/dev/null || ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
rm -f /etc/resolv.conf.m4build /etc/machine-id; : > /etc/machine-id
CHROOT
echo "== Done"
