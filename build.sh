#!/bin/bash

#
# Key preparation
#

set -e

CCACHE_USE=${CCACHE_USE:-1}

# Check we are in a container before we nuke the pesign dir
if [ -z "$container" ]; then
    echo "Error: This script should be run inside the build container."
    exit 1
fi

# Use two keys. In the action, these will get prefilled with the public
# keys from this directory

mkdir -p certs
for key in 101 102; do
    if [ ! -f certs/ubmok$key.priv ] || [ ! -f certs/ubmok$key.der ]; then
        echo "!! Warning. Creating ubmok$key for test build."
        openssl req -new -x509 -newkey rsa:2048 -keyout certs/ubmok$key.priv -out certs/ubmok$key.der -nodes -days 36500 -subj "/CN=ubluetestkey$key/"
    fi

    # Create pkcs12 file
    if [ ! -f certs/ubmok$key.p12 ]; then
        openssl pkcs12 -export -out certs/ubmok$key.p12 -inkey certs/ubmok$key.priv -in certs/ubmok$key.der -passout pass:
    fi
done


# Create NSS database and enroll keys
rm -rf ./certs/pki/ubluesign
mkdir -p ./certs/pki/ubluesign
certutil -N -d sql:./certs/pki/ubluesign --empty-password

# Import pkcs12 files
for key in 101 102; do
    certutil -A -d sql:./certs/pki/ubluesign -n "ubmok$key" -t "CT,C,C" -i certs/ubmok$key.der
    pk12util -i certs/ubmok$key.p12 -d sql:./certs/pki/ubluesign -W ""
done

# List keys
echo "Secure Boot Key status:"
certutil -L -d sql:./certs/pki/ubluesign

#
# Sources preparation
#

# Get the tarfile_release value from the spec file and download it
ARCH=${ARCH:-x86_64}
TARFILE_RELEASE=$(sed -n 's/^%define[[:space:]]\+tarfile_release[[:space:]]\+//p' kernel.spec)
NVIDIA_RELEASE=$(sed -n 's/^%define[[:space:]]\+nvidia_version[[:space:]]\+//p' kernel.spec)
NVIDIA_RELEASE_REL=$(sed -n 's/^%define[[:space:]]\+nvidia_version_rel[[:space:]]\+//p' kernel.spec)
NVIDIA_RELEASE_LTS=$(sed -n 's/^%define[[:space:]]\+nvidia_version_lts[[:space:]]\+//p' kernel.spec)
ZFS_RELEASE=$(sed -n 's/^%define[[:space:]]\+zfs_version[[:space:]]\+//p' kernel.spec)

echo "TARFILE_RELEASE is $TARFILE_RELEASE"
echo "NVIDIA_RELEASE is $NVIDIA_RELEASE"
echo "NVIDIA_RELEASE_LTS is $NVIDIA_RELEASE_LTS"
echo "ZFS_RELEASE is $ZFS_RELEASE"

echo "$TARFILE_RELEASE" > .tarfile-release
echo "$NVIDIA_RELEASE" > .nvidia-release
echo "$NVIDIA_RELEASE_LTS" > .nvidia-lts-release
echo "$ZFS_RELEASE" >> .zfs-release

if [ -z "$TARFILE_RELEASE" ] || [ -z "$NVIDIA_RELEASE" ] || [ -z "$ZFS_RELEASE" ]; then
    echo "Error: Could not determine TARFILE_RELEASE, NVIDIA_RELEASE, or ZFS_RELEASE from kernel.spec"
    exit 1
fi

linuxfn="linux-${TARFILE_RELEASE}.tar.xz"
zfsfn="zfs-${ZFS_RELEASE}.tar.gz"

if [ ! -f "$linuxfn" ]; then
    echo "Downloading $linuxfn"
    curl -L -o "$linuxfn" "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${TARFILE_RELEASE}.tar.xz"
fi
if [ ! -f "$zfsfn" ]; then
    echo "Downloading $zfsfn"
    curl -L -o "$zfsfn" \
        "https://github.com/openzfs/zfs/releases/download/zfs-${ZFS_RELEASE}/zfs-${ZFS_RELEASE}.tar.gz"
fi

nvreleases=($NVIDIA_RELEASE)
if [ "$NVIDIA_RELEASE" != "$NVIDIA_RELEASE_LTS" ]; then
    nvreleases+=($NVIDIA_RELEASE_LTS)
fi

#
# Open source driver
#

ofn="nvidia-kmod-${ARCH}-${NVIDIA_RELEASE}-${NVIDIA_RELEASE_REL}.tar.gz"
if [ ! -f "$ofn" ]; then
    echo "Downloading open source NVIDIA driver for release $NVIDIA_RELEASE"
    curl -L -o nvidia-kmod-${ARCH}-${NVIDIA_RELEASE}-${NVIDIA_RELEASE_REL}.tar.gz\
        https://github.com/NVIDIA/open-gpu-kernel-modules/archive/refs/tags/${NVIDIA_RELEASE}.tar.gz 
fi

#
# Closed legacy driver
#

nvrelease=$NVIDIA_RELEASE_LTS
# We need to do this to strip the driver from the srpm. Keeping two of
# Them would be a nice 800MB, here we drop to 160MB. We could halve
# that if we only keep the closed for LTS.
echo "Processing NVIDIA release $nvrelease for arch $ARCH"
RUN_FN="NVIDIA-Linux-$ARCH-${nvrelease}.run"
tarfn="nvidia-kmod-${ARCH}-${nvrelease}.tar.xz"

if [ ! -f "$RUN_FN" ]; then
    echo "Downloading $RUN_FN"
    curl -L -o $RUN_FN \
                "https://download.nvidia.com/XFree86/Linux-$ARCH/${nvrelease}/NVIDIA-Linux-$ARCH-${nvrelease}.run"
fi

rm -rf build/nvidia
mkdir -p build/nvidia/kmod

chmod +x $RUN_FN
./$RUN_FN --extract-only --target build/nvidia/extract

mv build/nvidia/extract/kernel/* build/nvidia/kmod

XZ_OPT='-T0' tar --remove-files -cJf $tarfn -C build/nvidia/kmod .
echo "Created $tarfn"
rm -rf build/nvidia

#
# Build
#

FEDORA_VERSION=${FEDORA_VERSION:-43}

echo "Starting build for Fedora $FEDORA_VERSION, arch $ARCH"
unset ARCH # There seems to be an issue here

sudo rm -rf /etc/pki/pesign
sudo cp -r certs/pki/ubluesign /etc/pki/pesign
sudo chown -R root:root /etc/pki/pesign
sudo chmod -R 755 /etc/pki/pesign

if [ "$CCACHE_USE" -eq 1 ]; then
    echo "Using ccache for build"
    export PATH="/usr/lib64/ccache:/usr/lib/ccache:$PATH"
    export CC="ccache gcc"
    export CXX="ccache g++"
    export CCACHE_MAXSIZE="5G"
    export CCACHE_DIR="$(pwd)/ccache"
fi

rpmbuild \
  --define '_topdir   %(pwd)/build' \
  --define '_builddir %{_topdir}/BUILD' \
  --define '_rpmdir   %{_topdir}/RPMS' \
  --define '_srcrpmdir %{_topdir}/SRPMS' \
  --define '_sourcedir %(pwd)/' \
  --define '_specdir  %(pwd)/' \
  --with bazzite --with ubsb --with nvidia --with zfs \
  -ba kernel.spec &

trap 'pkill --signal=SIGKILL -P $$; exit 130' INT
wait
