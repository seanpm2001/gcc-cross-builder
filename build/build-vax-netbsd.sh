#!/bin/bash

set -exuo pipefail

## This script uses NetBSD script to build the cross gcc, and will only use what
## they are using, which is fixed and not configurable. Currently, it's 10.4.0
VERSION=10.4.0

TARGET=vax-netbsd-elf

OUTPUT=/home/gcc-user/${TARGET}-gcc-${VERSION}.tar.xz
STAGING_DIR=/opt/compiler-explorer/${TARGET}/gcc-${VERSION}
export CT_PREFIX=${STAGING_DIR}

ARG1=${1:-}
FULLNAME=${TARGET}-gcc-${VERSION}
if [[ $ARG1 =~ s3:// ]]; then
    S3OUTPUT=$ARG1
else
    S3OUTPUT=""
    if [[ -d "${ARG1}" ]]; then
        OUTPUT="${ARG1}/${FULLNAME}.tar.xz"
    else
        OUTPUT=${1-/home/gcc-user/${FULLNAME}.tar.xz}
    fi
fi

## Build script from jbglaw https://github.com/compiler-explorer/compiler-explorer/issues/4783#issuecomment-1447028024
## with minor tweaks
GIT_NETBSD_SRC=NetBSD-src
WORKDIR=/opt/build-netbsd
RELEASEDIR="${WORKDIR}/rel"
DESTDIR="${WORKDIR}/dest"
TOOLDIR="${WORKDIR}/tools"

FINAL_ROOT="${WORKDIR}/gcc-${VERSION}"
FINAL_SYSROOT="${FINAL_ROOT}/vax--netbdself-sysroot"

NB_ARCH=vax
NB_MACHINE=vax

rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}"
pushd "${WORKDIR}"
    git clone -q --depth 1 --single-branch https://github.com/NetBSD/src.git "${GIT_NETBSD_SRC}"
	pushd "${GIT_NETBSD_SRC}"
		./build.sh -P -U -m "${NB_MACHINE}" -a "${NB_ARCH}" -E -D "${DESTDIR}" -R "${RELEASEDIR}" -T "${TOOLDIR}" tools libs
	popd

    ## Move stuff around
    mv tools "${FINAL_ROOT}"
    mv dest  "${FINAL_SYSROOT}"

    ## Sanity check
	printf 'int main(int argc, char *argv[]) {return argc*4+3;}\n' > t.c
	"${FINAL_ROOT}/bin/vax--netbsdelf-gcc" --sysroot="${FINAL_SYSROOT}" -o t t.c
	"${FINAL_ROOT}/bin/vax--netbsdelf-objdump" -Sw t
popd
## End of build

export XZ_DEFAULTS="-T 0"
tar Jcf "${OUTPUT}" -C "${WORKDIR}" "gcc-${VERSION}"

if [[ -n "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi

echo "ce-build-status:OK"