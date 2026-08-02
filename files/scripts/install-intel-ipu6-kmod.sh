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
    chmod
    chown
    runuser
    stat
    bash
    cat
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

echo "Installing akmods build environment"

dnf5 -y install \
    "kernel-devel-${kernel_release}" \
    akmods

if ! command -v akmodsbuild >/dev/null 2>&1; then
    echo "ERROR: akmodsbuild was not installed with the akmods package." >&2
    exit 1
fi

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

echo "Downloaded RPM:"
echo "  ${akmod_rpm}"

echo "Installing akmod source payload without scriptlets"

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

source_rpm="$(
    find /usr/src/akmods \
        -maxdepth 1 \
        -type f \
        -name 'intel-ipu6-kmod-*.src.rpm' \
        -print \
        -quit
)"

if [[ -z "${source_rpm}" ]]; then
    echo "ERROR: Intel IPU6 source RPM was not installed." >&2
    rpm -ql akmod-intel-ipu6 >&2
    exit 1
fi

echo "Intel IPU6 source RPM:"
echo "  ${source_rpm}"

echo "Preparing writable temporary directories"

chmod 1777 /tmp /var/tmp

echo "Temporary directory permissions:"
stat -c '%A %a %U:%G %n' /tmp /var/tmp

echo "Testing temporary-directory access as the akmods user"

runuser -u akmods -- bash -c '
    set -euo pipefail

    tmp_test="$(mktemp -d /tmp/gooseos-akmods-test.XXXXXXXX)"
    var_tmp_test="$(mktemp /var/tmp/gooseos-akmods-test.XXXXXXXX)"

    mkdir "${tmp_test}/BUILD"
    touch "${tmp_test}/BUILD/write-test"

    rm -rf "${tmp_test}"
    rm -f "${var_tmp_test}"
'

echo "Temporary-directory access test passed"

build_output_dir="${workdir}/built-rpms"
build_log="${workdir}/akmodsbuild.log"

mkdir -p "${build_output_dir}"
touch "${build_log}"

chmod 0755 "${workdir}"
chown akmods:akmods "${build_output_dir}"
chown akmods:akmods "${build_log}"

echo "Building Intel IPU6 RPM for ${kernel_release}"
echo "Running akmodsbuild directly as the akmods user"

if ! runuser -u akmods -- /usr/sbin/akmodsbuild \
    --kernels "${kernel_release}" \
    --outputdir "${build_output_dir}" \
    --logfile "${build_log}" \
    "${source_rpm}"; then

    echo "ERROR: Intel IPU6 RPM build failed." >&2

    echo "akmodsbuild log:" >&2
    cat "${build_log}" >&2 || true

    echo "Build output files:" >&2
    find "${build_output_dir}" \
        -maxdepth 1 \
        -type f \
        -print >&2 || true

    exit 1
fi

mapfile -t built_kmod_rpms < <(
    find "${build_output_dir}" \
        -maxdepth 1 \
        -type f \
        -name "kmod-intel-ipu6-${kernel_release}-*.rpm" \
        -print
)

if (( ${#built_kmod_rpms[@]} != 1 )); then
    echo "ERROR: Expected exactly one Intel IPU6 kmod RPM." >&2

    echo "Build output files:" >&2
    find "${build_output_dir}" \
        -maxdepth 1 \
        -type f \
        -print >&2 || true

    echo "akmodsbuild log:" >&2
    cat "${build_log}" >&2 || true

    exit 1
fi

built_kmod_rpm="${built_kmod_rpms[0]}"

echo "Built Intel IPU6 RPM:"
echo "  ${built_kmod_rpm}"

echo "Built RPM metadata:"
rpm -qip "${built_kmod_rpm}"

echo "Installing the built kmod and ipu6-camera-bins together"

dnf5 -y install \
    "${built_kmod_rpm}" \
    ipu6-camera-bins

depmod -a "${kernel_release}"

kmod_package="kmod-intel-ipu6-${kernel_release}"

if ! rpm -q "${kmod_package}" >/dev/null 2>&1; then
    echo "ERROR: Expected kmod package was not installed:" >&2
    echo "  ${kmod_package}" >&2

    echo "Available Intel IPU6 packages:" >&2
    rpm -qa | grep -E 'intel-ipu6|ipu6-camera' >&2 || true

    echo "akmodsbuild log:" >&2
    cat "${build_log}" >&2 || true

    echo "Built RPM files:" >&2
    find "${build_output_dir}" \
        -maxdepth 1 \
        -type f \
        -print >&2 || true

    exit 1
fi

if ! rpm -q --whatprovides intel-ipu6-kmod-common >/dev/null 2>&1; then
    echo "ERROR: Nothing provides intel-ipu6-kmod-common." >&2
    exit 1
fi

if ! rpm -q --whatprovides intel-ipu6-kmod >/dev/null 2>&1; then
    echo "ERROR: Nothing provides intel-ipu6-kmod." >&2
    exit 1
fi

echo "Intel IPU6 dependency providers:"

echo "intel-ipu6-kmod-common:"
rpm -q --whatprovides intel-ipu6-kmod-common

echo "intel-ipu6-kmod:"
rpm -q --whatprovides intel-ipu6-kmod

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
echo "Intel IPU6 kmod build and installation completed successfully."
