#!/usr/bin/env bash
set -euo pipefail

required_commands=(
    rpm
    dnf5
    depmod
    find
    grep
    sort
    tail
)

for command_name in "${required_commands[@]}"; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        echo "ERROR: Required build command is missing: ${command_name}" >&2
        exit 1
    fi
done

kernel_release="$(
    rpm -q kernel-core \
        --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' |
        sort -V |
        tail -n 1
)"

if [[ -z "${kernel_release}" ]]; then
    echo "ERROR: Could not determine the image kernel release." >&2
    exit 1
fi

echo "Kernel release: ${kernel_release}"
echo "Preparing Intel IPU6 akmod build"

created_ostree_marker=0

cleanup() {
    if (( created_ostree_marker == 1 )); then
        rm -f /run/ostree-booted
    fi
}

trap cleanup EXIT

#
# Fedora 44 workaround:
#
# Installing akmod-intel-ipu6 normally runs akmods-ostree-post during the
# RPM transaction. In a bootc/BlueBuild container this fails with:
#
#   ERROR: Not to be used as root; start as user or 'akmodsbuild' instead.
#
# Present the build temporarily as an OSTree system so the package installs
# without building the kmod in its RPM %post script. Then run akmods
# explicitly after the RPM transaction is complete.
#

if [[ ! -e /run/ostree-booted ]]; then
    touch /run/ostree-booted
    created_ostree_marker=1
fi

echo "Installing Intel IPU6 akmod source and build dependencies"

dnf5 -y install \
    "kernel-devel-${kernel_release}" \
    akmod-intel-ipu6

if (( created_ostree_marker == 1 )); then
    rm -f /run/ostree-booted
    created_ostree_marker=0
fi

if ! command -v akmods >/dev/null 2>&1; then
    echo "ERROR: akmods was not installed." >&2
    exit 1
fi

echo "Building Intel IPU6 modules for ${kernel_release}"

if ! akmods \
    --force \
    --kernels "${kernel_release}" \
    --kmod intel-ipu6; then

    echo "ERROR: Intel IPU6 akmod build failed." >&2

    find /var/cache/akmods/intel-ipu6 \
        -type f \
        -name '*.log' \
        -print \
        -exec cat {} \; 2>/dev/null || true

    exit 1
fi

depmod -a "${kernel_release}"

kmod_package="kmod-intel-ipu6-${kernel_release}"

if ! rpm -q "${kmod_package}" >/dev/null 2>&1; then
    echo "ERROR: Expected package was not installed: ${kmod_package}" >&2

    echo "Available Intel IPU6 packages:"
    rpm -qa | grep -E '(^|-)intel-ipu6' || true

    echo "Akmods build logs:"
    find /var/cache/akmods/intel-ipu6 \
        -type f \
        -name '*.log' \
        -print \
        -exec cat {} \; 2>/dev/null || true

    exit 1
fi

mapfile -t module_files < <(
    rpm -ql "${kmod_package}" |
        grep -E '\.ko(\.(xz|zst|gz))?$' || true
)

if (( ${#module_files[@]} == 0 )); then
    echo "ERROR: No kernel modules found in ${kmod_package}." >&2
    rpm -ql "${kmod_package}" >&2
    exit 1
fi

echo "Installed package:"
rpm -q "${kmod_package}"

echo "Installed Intel IPU6 kernel modules:"
printf '  %s\n' "${module_files[@]}"

for module_file in "${module_files[@]}"; do
    echo
    echo "Module information: ${module_file}"

    modinfo "${module_file}" |
        grep -E '^(filename|name|vermagic|signer|sig_key|sig_hashalgo):' ||
        true
done

echo
echo "Intel IPU6 kmod build completed successfully."
