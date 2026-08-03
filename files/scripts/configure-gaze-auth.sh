#!/usr/bin/env bash
set -euo pipefail

if [[ ! -d /usr/share/authselect/vendor/gaze ]]; then
    echo "ERROR: Gaze authselect profile is not installed." >&2
    exit 1
fi

echo "Enabling Gaze PAM authentication"

authselect select gaze \
    with-silent-lastlog \
    with-mdns4 \
    with-fingerprint \
    --force

authselect check

echo "Active authselect configuration:"
authselect current

echo "Gaze PAM entries:"
grep -n pam_gaze \
    /etc/pam.d/system-auth \
    /etc/pam.d/password-auth