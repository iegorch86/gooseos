#!/usr/bin/env bash
set -euxo pipefail

echo "=== Available akmod RPMs ==="
find /tmp/rpms -maxdepth 1 -type f | sort

echo "=== Search v4l2/ip u6 ==="
find /tmp/rpms -maxdepth 1 -type f | grep -Ei 'v4l2|ipu6' || true
