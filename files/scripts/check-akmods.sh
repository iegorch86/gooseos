#!/usr/bin/env bash
set -euxo pipefail

echo "=== AKMOD CONTENTS ==="
find /tmp/rpms -maxdepth 1 -type f -printf '%f\n' | sort

echo
echo "=== V4L2/IPU6 SEARCH ==="
find /tmp/rpms -maxdepth 1 -type f | grep -Ei 'v4l2|ipu6' || true
