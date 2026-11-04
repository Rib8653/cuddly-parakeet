#!/bin/bash
# Run build.sh inside an Ubuntu 26.04 container. Use this on non-Debian hosts,
# e.g. Omarchy (Arch) on the M4 Air itself, where it runs natively on arm64.
#   ./build-in-docker.sh            # output: ./work/kit
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
command -v docker >/dev/null || { echo "Install Docker first." >&2; exit 1; }
sudo systemctl start docker 2>/dev/null || true
# --privileged: the build loop-mounts the root filesystem images.
exec sudo docker run --rm --privileged -v "$HERE:/ubuntu-m4" -w /ubuntu-m4 \
  ubuntu:26.04 bash -c 'apt-get update -q && ./build.sh /ubuntu-m4/work'
