#!/bin/bash
# Run build.sh inside an Ubuntu 26.04 container.
# Works on macOS (Docker Desktop or Colima, Apple Silicon) and on non-Debian
# Linux such as Omarchy. Output: ./work/kit
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
command -v docker >/dev/null || { echo "Install Docker Desktop (or Colima) first." >&2; exit 1; }

SUDO=sudo
if [ "$(uname -s)" = Darwin ]; then
  SUDO=   # Docker on macOS runs as your user
else
  sudo systemctl start docker 2>/dev/null || true
fi
if ! $SUDO docker info >/dev/null 2>&1; then
  echo "The Docker engine is not running." >&2
  echo "  Docker Desktop: open -a Docker   (wait for it to say 'running', then retry)" >&2
  echo "  Colima:         colima start --cpu 4 --memory 8 --disk 80" >&2
  exit 1
fi
if [ "$($SUDO docker info --format '{{.Architecture}}')" != aarch64 ]; then
  echo "Note: Docker is not arm64; the build will use slow emulation." >&2
fi

# --patch-kit: update an existing ./work/kit with the current overlay only.
if [ "${1:-}" = --patch-kit ]; then
  [ -d "$HERE/work/kit/os" ] || { echo "No kit at $HERE/work/kit" >&2; exit 1; }
  exec $SUDO docker run --rm --privileged \
    -v "$HERE:/ubuntu-m4:ro" -v "$HERE/work/kit:/kit" \
    ubuntu:26.04 bash -c 'apt-get update -q >/dev/null && apt-get install -y -q python3 e2fsprogs >/dev/null && /ubuntu-m4/patch-kit.sh /kit /tmp/patch'
fi

# Build inside a Docker volume (the 16 GB disk images must live on a real
# Linux filesystem for loop mounts), then copy only the finished kit out.
VOL=ubuntu-m4-work
$SUDO docker volume create "$VOL" >/dev/null
mkdir -p "$HERE/work"
exec $SUDO docker run --rm --privileged \
  -v "$HERE:/ubuntu-m4:ro" -v "$VOL:/work" -v "$HERE/work:/out" \
  ubuntu:26.04 bash -c '
    set -e
    apt-get update -q
    /ubuntu-m4/build.sh /work
    rm -rf /out/kit && cp -a /work/kit /out/kit
    echo "Kit copied to ubuntu-m4/work/kit"
    echo "Free the build space afterwards with: docker volume rm ubuntu-m4-work"'
