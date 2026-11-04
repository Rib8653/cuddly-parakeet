# ubuntu-m4: Ubuntu 26.04 on the 13-inch M4 MacBook Air

Builds an installer kit that keeps the
[Omarchy-M4-Native](https://github.com/Kb2uka/Omarchy-M4-Native)
v0.1.0-alpha.1-update.4 boot chain and M4 hardware stack unchanged and replaces
the Arch/Omarchy root filesystem with Ubuntu 26.04 LTS + GNOME.

Experimental, untested on hardware, J713 (Mac16,12) only. End-user steps are in
[START-HERE.md](START-HERE.md), which is also copied into the kit.

## Build

On an Ubuntu/Debian machine with root and ~35 GB free (an arm64 host is much
faster; x86_64 uses qemu-user emulation):

```sh
sudo ./build.sh            # output: ./work/kit
```

On any other Linux with Docker, including Omarchy on the M4 Air itself
(native arm64, the fastest option):

```sh
./build-in-docker.sh       # output: ./work/kit
```

To update an existing kit after `git pull` without rebuilding Ubuntu:
`./build-in-docker.sh --patch-kit` (or `sudo ./patch-kit.sh work/kit` on Linux).

`build.sh` downloads update.4 and verifies it against the release manifest
(pinned), extracts the Omarchy root image, bootstraps Ubuntu (`bootstrap.sh`),
applies the M4 layer (`port-m4-layer.sh`) and writes the kit (`make-kit.sh`).

## What carries over, and how

| Piece | Source | Treatment |
|---|---|---|
| m1n1 stage 1, kernel, devicetree, initramfs | update.4 `installer-macos.tar.gz` and OS zip `boot/` | Unchanged; the installer verifies their pinned hashes |
| Installer (macOS) | update.4 | Unchanged; only `installer_data.json` names and `Install.command` messages differ |
| Files in [`m4-files.txt`](m4-files.txt) | update.4 `root.ext4` | Copied byte-for-byte and re-verified with sha256 |
| Ubuntu-specific settings | [`overlay/`](overlay) | No suspend, GDM ordering, M4 GPU hidden from Ubuntu's M1/M2 drivers, opt-in GPU session, apt pins |
| Browser | Ubuntu archive / Mozilla APT | GNOME Web always; Firefox (.deb) when packages.mozilla.org is reachable |

Why it can work: the update.4 initramfs only requires an ext4 root with
`/etc/m4-root-id`, `/usr/lib/systemd/systemd` and `/usr/lib/firmware`. The
installer only checks the root filesystem UUID (reused). Ubuntu 26.04 ships
glibc 2.43, the same as the Arch build the M4 binaries were linked against. The
speaker readiness check verifies its own files, kernel and module build IDs at
runtime, so it should pass with the byte-identical copies.

Not ported: Omarchy's desktop, first-boot form, Brave/Widevine, boot-status
notice, and the pacman update channel (CPU scaling/boost, temperature, front
USB-C, headphones and brightness arrive only through it).

## Licensing

Copied files keep their upstream licenses; see the kit's `notices/` and
Omarchy-M4-Native's `LICENSE.md` / `THIRD_PARTY_NOTICES.md`. The kit reuses
GPL-2.0 kernel binaries; the corresponding source is in the update.4 release
companion (`source/`). Do not redistribute a built kit without carrying that
source and those notices.

## Verified in the build environment (no M4 hardware)

- Every file in `m4-files.txt` is byte-identical to update.4 (sha256).
- The protected-speaker manifest: all 29 pinned files match; the video
  manifest's 43 pinned files match apart from the deliberately omitted
  Brave/Chromium/Widevine files.
- `speakersafetyd-j713`, the M4 Mesa libraries and the VA-API driver load
  against Ubuntu 26.04's libraries with full symbol binding (`LD_BIND_NOW=1`).
- The installer's own `m4boot` code accepts the kit's boot spec and pinned
  files, and the root image carries the expected filesystem UUID.
- The ext4 feature set is a subset of update.4's root image; the update.4
  initramfs ships e2fsprogs 1.47.4.

Not verifiable without the Air: that GNOME starts on simpledrm, that the GPU
opt-in works with GNOME, Wi-Fi/Bluetooth/input behaviour on Ubuntu, and the
installer run itself.
