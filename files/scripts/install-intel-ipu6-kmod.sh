#!/usr/bin/env bash
set -euo pipefail

required_commands=(
    rpm
    dnf5
    depmod
    modinfo
    find
    grep
    sort
    tail
    mktemp
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

architecture="$(rpm -E '%_arch')"
workdir="$(mktemp -d)"

cleanup() {
    rm -rf "${workdir}"
}
trap cleanup EXIT

echo "Kernel release: ${kernel_release}"
echo "Architecture: ${architecture}"

#
# Install the build environment first.
# Do not install akmod-intel-ipu6 through DNF here because its RPM %post
# attempts to build inside the transaction and fails in BlueBuild.
#

echo "Installing akmods build environment"

dnf5 -y install \
    "kernel-devel-${kernel_release}" \
    akmods

#
# Some Fedora images provide the DNF5 download command through dnf5-plugins.
#

if ! dnf5 download --help >/dev/null 2>&1; then
    echo "Installing DNF5 download support"
    dnf5 -y install dnf5-plugins
fi

echo "Downloading akmod-intel-ipu6 without installing it"

dnf5 download \
    --destdir="${workdir}" \
    --arch="${architecture}" \
    akmod-intel-ipu6

mapfile -t akmod_rpms < <(
    find "${workdir}" \
        -maxdepth 1 \
        -type f \
        -name 'akmod-intel-ipu6-*.rpm' \
        -print
)

if (( ${#akmod_rpms[@]} != 1 )); then
    echo "ERROR: Expected exactly one akmod-intel-ipu6 RPM." >&2
    echo "Downloaded files:" >&2
    find "${workdir}" -maxdepth 1 -type f -print >&2
    exit 1
fi

akmod_rpm="${akmod_rpms[0]}"

echo "Downloaded RPM: ${akmod_rpm}"

#
# Install only the akmod source payload.
#
# --noscripts prevents the failing akmods-ostree-post call.
# --notriggers prevents transaction triggers associated with this manual
# installation. We will build the actual kmod explicitly afterward.
#

echo "Installing akmod source package without RPM scriptlets"

rpm -Uvh \
    --noscripts \
    --notriggers \
    --nodeps \
    "${akmod_rpm}"

if ! rpm -q akmod-intel-ipu6 >/dev/null 2>&1; then
    echo "ERROR: akmod-intel-ipu6 was not installed." >&2
    exit 1
fi

echo "Installed akmod source package:"
rpm -q akmod-intel-ipu6

echo "Available Intel IPU6 source RPM:"
find /usr/src/akmods \
    -maxdepth 1 \
    -type f \
    -name 'intel-ipu6-kmod-*.src.rpm' \
    -print

source_rpm="$(
    find /usr/src/akmods \
        -maxdepth 1 \
        -type f \
        -name 'intel-ipu6-kmod-*.src.rpm' \
        -print \
        -quit
)"

if [[ -z "${source_rpm}" ]]; then
    echo "ERROR: Intel IPU6 akmod source RPM was not installed." >&2
    rpm -ql akmod-intel-ipu6 >&2
    exit 1
fi

echo "Building Intel IPU6 modules for ${kernel_release}"

if ! akmods \
    --force \
    --kernels "${kernel_release}" \
    --kmod intel-ipu6; then

    echo "ERROR: Intel IPU6 akmod build failed." >&2

    echo "Akmods logs:"
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
    echo "ERROR: Expected kmod package was not installed:" >&2
    echo "  ${kmod_package}" >&2

    echo "Available Intel IPU6 packages:"
    rpm -qa | grep -E 'intel-ipu6' || true

    echo "Akmods logs:"
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
    echo "ERROR: No kernel modules were found in ${kmod_package}." >&2
    rpm -ql "${kmod_package}" >&2
    exit 1
fi

echo "Installed kmod package:"
rpm -q "${kmod_package}"

echo "Installed Intel IPU6 modules:"
printf '  %s\n' "${module_files[@]}"

for module_file in "${module_files[@]}"; do
    echo
    echo "Module information: ${module_file}"

    modinfo "${module_file}" |
        grep -E \
            '^(filename|name|version|vermagic|signer|sig_key|sig_hashalgo):' ||
        true
done

echo
echo "Intel IPU6 kmod build completed successfully."
