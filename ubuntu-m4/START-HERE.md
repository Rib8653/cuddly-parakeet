# Ubuntu 26.04 on the 13-inch M4 MacBook Air — EXPERIMENTAL

**Only for the 13-inch M4 MacBook Air (2025), Mac16,12 / J713.** The installer
refuses every other Mac.

This kit is **Ubuntu 26.04 LTS with GNOME**, booted by the exact
[Omarchy-M4-Native](https://github.com/Kb2uka/Omarchy-M4-Native)
v0.1.0-alpha.1-update.4 boot chain: same m1n1, kernel
`7.1.9-m4-gpu-backport-20261008`, devicetree, initramfs, GPU module, Mesa,
video decoder and protected speaker stack, copied byte-for-byte. Only the
operating system on top is Ubuntu instead of Arch/Omarchy.

It is an independent experiment. It is **not** endorsed by Omarchy-M4-Native,
Omarchy, Asahi Linux, Canonical or Apple, and **has not been tested on
hardware**. Installing changes partitions and boot policy and can cause data
loss. Back up your Mac (Time Machine) before you start. macOS stays installed.

## What to expect

| Part | Ubuntu M4 |
|---|---|
| Desktop | GNOME on the built-in panel, **software rendering** by default |
| M4 GPU acceleration | Experimental opt-in: `sudo ubuntu-m4-gpu on`, then log out |
| Keyboard, trackpad, Wi-Fi, Bluetooth | Same kernel drivers as Omarchy-M4-Native |
| Speakers | Protected by the same pinned `speakersafetyd-j713`; they stay off if any integrity check fails |
| USB-C | Hinge-side port only (the front-port fix ships through Omarchy's update channel, not here) |
| Shut Down | Uses the update.4 power-off devicetree |
| Suspend, lid sleep | **Disabled on purpose** (unsupported on M4) |
| External displays, camera | Not supported |
| Updates | `sudo apt upgrade` for Ubuntu software. Ubuntu kernels and snaps are blocked; the M4 kernel never changes through apt |

Not included from Omarchy-M4-Native's update channel (it is pacman-based):
CPU frequency scaling/boost, CPU temperature, front USB-C port, headphone jack,
brightness keys. The CPUs run at the boot-default speed.

## 1. Remove Omarchy (you chose to replace it)

The installer needs free space where Omarchy is now. Disk numbers differ on
every Mac, so **do not copy commands from anyone else's machine**:

1. Boot macOS. In Terminal run `diskutil list` and keep the output.
2. Omarchy uses three partitions: a small APFS container (~2.5 GB) holding its
   boot stub, an `EFI` FAT partition (500 MB), and a Linux partition (the big
   one). Delete exactly those three, leaving macOS, its recovery and the Apple
   system containers alone. If unsure, ask (or share the `diskutil list` output)
   before deleting anything.

## 2. Install (macOS)

Copy this whole folder to the Mac (or an exFAT USB drive, hinge-side port).
Connect power, then in Terminal:

```sh
cd /path/to/kit        # the folder containing this file
bash Install.command --install
```

1. Wait for the checksum lines to finish (the OS image takes a few minutes).
2. Answer `y`, then `N` for Widevine (unused by Ubuntu).
3. Enter your **macOS** password (nothing shows while you type).
4. The installer runs in expert mode. Choose **Ubuntu 26.04 M4**.
5. Choose **Install into free space**, answer `max` for the size, and name the
   OS **Ubuntu M4**.
6. Follow the on-screen recovery steps exactly; Apple requires you to approve
   the new OS with your macOS account. Do not cut power while it writes.

It needs macOS 26.5.1 or newer, the same as Omarchy-M4-Native update.4.

## 3. First boot

Choose **Ubuntu M4** at startup. The first boot grows the filesystem, so it
takes a little longer. **GNOME Initial Setup** then asks for language,
keyboard, Wi-Fi, time zone, and creates your account.

If the screen stays on text: press **Control + Option + F3** (add Fn if needed),
log in, and collect:

```sh
sudo journalctl -b -u gdm -u m4-gpu -u m4-video --no-pager | tail -80
```

## Trying GPU acceleration

By default the M4 GPU is hidden from GNOME and apps: Ubuntu's own Asahi
graphics drivers only know M1/M2 GPUs, and letting them touch the M4 GPU can
hang it until the Mac resets. Only Omarchy-M4-Native's M4 Mesa may use it:

```sh
sudo ubuntu-m4-gpu on     # then log out and back in
sudo ubuntu-m4-gpu status
```

If GNOME fails to come back (black screen or login loop): restart, press
Control + Option + F3, log in, run `sudo ubuntu-m4-gpu off`, then restart.

## Going back to macOS

Shut down, hold the power button until **Loading startup options**, choose
**Macintosh HD**.
