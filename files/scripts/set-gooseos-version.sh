#!/usr/bin/env bash
set -euo pipefail

OS_RELEASE="/usr/lib/os-release"
BUILD_DATE="$(date -u +%Y-%m-%d)"

source "${OS_RELEASE}"

# Ensure the file ends with a newline before appending new fields.
sed -i -e '$a\' "${OS_RELEASE}"

case "${IMAGE_NAME:?BlueBuild did not provide IMAGE_NAME}" in
    *intel*)
        EDITION="Intel/AMD"
        ;;
    *nvidia*)
        EDITION="nvidia-open"
        ;;
    *cosmic-test*|*testing*)
        EDITION="COSMIC Test"
        ;;
    *)
        echo "Cannot determine GooseOS edition from IMAGE_NAME=${IMAGE_NAME}" >&2
        exit 1
        ;;
esac

BASE_VERSION="${IMAGE_VERSION:-${OSTREE_VERSION:-}}"

if [[ -z "${BASE_VERSION}" ]]; then
    BASE_VERSION="$(
        printf '%s\n' "${VERSION:-}" |
        grep -oE '[0-9]+\.[0-9]{8}\.[0-9]+' |
        head -n1
    )"
fi

if [[ -z "${BASE_VERSION}" ]]; then
    echo "Cannot determine base-image version from ${OS_RELEASE}" >&2
    cat "${OS_RELEASE}" >&2
    exit 1
fi

RELEASE_CHANNEL="${RELEASE_TYPE:-stable}"

PRETTY_NAME_VALUE="GooseOS-${EDITION} build:${BUILD_DATE} version:${BASE_VERSION}:${RELEASE_CHANNEL}"

sed -i \
    -e 's/^NAME=.*/NAME="GooseOS"/' \
    -e 's/^ID=.*/ID=gooseos/' \
    -e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"${PRETTY_NAME_VALUE}\"|" \
    -e 's/^DEFAULT_HOSTNAME=.*/DEFAULT_HOSTNAME="gooseos"/' \
    "${OS_RELEASE}"

if grep -q '^BUILD_DATE=' "${OS_RELEASE}"; then
    sed -i \
        "s/^BUILD_DATE=.*/BUILD_DATE=\"${BUILD_DATE}\"/" \
        "${OS_RELEASE}"
else
    printf 'BUILD_DATE="%s"\n' "${BUILD_DATE}" >> "${OS_RELEASE}"
fi

printf 'Generated GooseOS identity:\n'
printf '  IMAGE_NAME=%s\n' "${IMAGE_NAME}"
printf '  EDITION=%s\n' "${EDITION}"
printf '  BASE_VERSION=%s\n' "${BASE_VERSION}"
printf '  BUILD_DATE=%s\n' "${BUILD_DATE}"
printf '  PRETTY_NAME=%s\n' "${PRETTY_NAME_VALUE}"
