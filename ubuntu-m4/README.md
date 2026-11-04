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

`build.sh` downloads update.4 and verifies it against the release manifest
(pinned), extracts the Omarchy root image, bootstraps Ubuntu (`bootstrap.sh`),
applies the M4 layer (`port-m4-layer.sh`) and writes the kit (`make-kit.sh`).

## What carries over, and how

| Piece | Source | Treatment |
|---|---|---|
| m1n1 stage 1, kernel, devicetree, initramfs | update.4 `installer-macos.tar.gz` and OS zip `boot/` | Unchanged; the installer verifies their pinned hashes |
| Installer (macOS) | update.4 | Unchanged; only `installer_data.json` names and `Install.command` messages differ |
| Files in [`m4-files.txt`](m4-files.txt) | update.4 `root.ext4` | Copied byte-for-byte and re-verified with sha256 |
| Ubuntu-specific settings | [`overlay/`](overlay) | No suspend, GDM ordering, opt-in GPU session, apt pins |

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
