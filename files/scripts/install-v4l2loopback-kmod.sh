#!/usr/bin/env bash
set -euo pipefail

required_commands=(
    rpm
    skopeo
    jq
    tar
    dnf5
    depmod
)

for command_name in "${required_commands[@]}"; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        echo "ERROR: Required build command is missing: ${command_name}" >&2
        exit 1
    fi
done

fedora_release="$(rpm -E '%fedora')"

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

akmods_tag="main-${fedora_release}-${kernel_release}"
akmods_image="docker://ghcr.io/ublue-os/akmods:${akmods_tag}"

workdir="$(mktemp -d)"
oci_dir="${workdir}/oci"
root_dir="${workdir}/root"

cleanup() {
    rm -rf "${workdir}"
}
trap cleanup EXIT

mkdir -p "${oci_dir}" "${root_dir}"

echo "Fedora release: ${fedora_release}"
echo "Kernel release: ${kernel_release}"
echo "Akmods image: ${akmods_image}"

skopeo copy \
    --retry-times 3 \
    "${akmods_image}" \
    "dir:${oci_dir}"

manifest="${oci_dir}/manifest.json"

if [[ ! -f "${manifest}" ]]; then
    echo "ERROR: Akmods OCI manifest was not downloaded." >&2
    exit 1
fi

while IFS= read -r digest; do
    layer="${oci_dir}/${digest#sha256:}"

    if [[ ! -f "${layer}" ]]; then
        echo "ERROR: OCI layer is missing: ${layer}" >&2
        exit 1
    fi

    tar -xzf "${layer}" -C "${root_dir}"
done < <(jq -r '.layers[].digest' "${manifest}")

shopt -s nullglob

kmod_rpms=(
    "${root_dir}"/rpms/kmods/*v4l2loopback*.rpm
)

userspace_rpms=(
    "${root_dir}"/rpms/common/v4l2loopback-*.rpm
)

addon_rpms=(
    "${root_dir}"/rpms/ublue-os/ublue-os-akmods*.rpm
)

if (( ${#kmod_rpms[@]} == 0 )); then
    echo "ERROR: No v4l2loopback kmod RPM was found for ${kernel_release}." >&2
    find "${root_dir}/rpms" -maxdepth 3 -type f -print 2>/dev/null || true
    exit 1
fi

if (( ${#userspace_rpms[@]} == 0 )); then
    echo "ERROR: No v4l2loopback userspace RPM was found." >&2
    find "${root_dir}/rpms" -maxdepth 3 -type f -print 2>/dev/null || true
    exit 1
fi

echo "Installing Universal Blue support RPMs:"
printf '  %s\n' "${addon_rpms[@]}"

echo "Installing v4l2loopback userspace RPMs:"
printf '  %s\n' "${userspace_rpms[@]}"

echo "Installing v4l2loopback kernel RPMs:"
printf '  %s\n' "${kmod_rpms[@]}"

install_rpms=(
    "${addon_rpms[@]}"
    "${userspace_rpms[@]}"
    "${kmod_rpms[@]}"
)

dnf5 -y install "${install_rpms[@]}"

depmod -a "${kernel_release}"

module_file="$(
    find "/usr/lib/modules/${kernel_release}" \
        -type f \
        -name 'v4l2loopback.ko*' \
        -print \
        -quit
)"

if [[ -z "${module_file}" ]]; then
    echo "ERROR: v4l2loopback module was not installed for ${kernel_release}." >&2
    exit 1
fi

echo "Installed module: ${module_file}"
modinfo -k "${kernel_release}" v4l2loopback

