# cuddly-parakeet — Asahi Linux M4 experiments

Vendored copies of Asahi Linux components, patched to experiment with the
**M4 MacBook Air** (`j713ap` 13-inch, `j715ap` 15-inch, SoC `t8132`).

> ⚠️ **M4 is NOT supported by upstream Asahi Linux (as of Nov 2026).**
> m1n1 can identify M4 CPUs and the kernel has M4 device trees queued for
> Linux 7.4, but there is no GPU driver, no supported boot firmware path, and
> Asahi says M4 is not ready for users. Expect a boot to m1n1 or a kernel
> console at best: no display driver, and possibly no storage, keyboard,
> or trackpad. Keep a working macOS install, and back up first.

## What's here

| Directory | Upstream | Upstream commit | Changes |
|---|---|---|---|
| `m1n1/` | AsahiLinux/m1n1 | `c5609da` | Fixed a build error from `-Wstrict-prototypes` in `src/hv/hv.c`; vendored `artwork/` (`80d14f8`) |
| `asahi-installer/` | AsahiLinux/asahi-installer | `e93743d` | M4 Air entries (expert mode only) + `ASAHI_M4_IPSW` override |

The kernel is too large to vendor. M4 device trees are on
`https://github.com/AsahiLinux/linux` branch `asahi-soc/for-next`
(`arch/arm64/boot/dts/apple/t8132-j713.dts`, `t8132-j715.dts`).

## Building m1n1

```sh
rustup target add aarch64-unknown-none-softfloat
cd m1n1 && make -j8 USE_CLANG=1     # -> build/m1n1.bin, build/m1n1.macho
```

## Installer patch

`asahi-installer/src/main.py` now recognizes chip `0x8132` and the M4 Air
models, but only in **expert mode**. Upstream has no macOS 15.x stub firmware
entry, and M4 Macs can't use the 14.8.3 one. So the installer stops unless you
supply a 15.x firmware entry yourself:

```sh
export ASAHI_M4_IPSW="<macOS ver>|<min macOS>|<min iBoot>|<min SFR>|<URL of Apple's 15.x IPSW/asset for your model>"
```

Take these values from Apple's real 15.x restore image for your device; the
installer doesn't verify them. There's a further risk: Asahi has reported that
macOS 15.x changed the NVMe controller firmware, so Linux may not see the
internal SSD even if everything else boots.

## Safer way to experiment: m1n1 proxy mode

Asahi developers bring up new Macs this way. Linux never touches your disk,
because everything is sent over USB from a second computer (your M4 Mac mini
works):

1. Use the patched installer in expert mode to create a small stub partition
   that boots `m1n1.macho` as a raw "proxy" (macOS stays as-is).
2. Connect the Air to the second computer with a USB-C cable.
3. On the second computer:
   `cd m1n1/proxyclient && M1N1DEVICE=/dev/cu.usbmodemXXXX python3 tools/chainload.py ../build/m1n1.bin`
   then `tools/linux.py` with a kernel `Image` + `t8132-j713.dtb` (or j715) built from the branch above.
4. To undo: boot macOS (hold the power button → Options), delete the stub
   partition in Disk Utility, and set macOS as the startup disk again.

Follow https://asahilinux.org/blog/ for real M4 support.
