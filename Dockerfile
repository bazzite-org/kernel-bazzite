ARG FEDORA_VERSION=44

FROM fedora:${FEDORA_VERSION}

RUN dnf install -y fedpkg fedora-packager rpmdevtools ncurses-devel pesign \
    asciidoc audit-libs-devel bc bindgen binutils-devel bison clang dwarves \
    elfutils-devel flex fuse-devel gcc gcc-c++ gettext glibc-static hostname \
    java-devel kernel-rpm-macros libbabeltrace-devel libbpf-devel ccache \
    libcap-devel libcap-ng-devel libmnl-devel libnl3-devel libtraceevent-devel \
    libtracefs-devel lld llvm-devel lvm2 m4 make net-tools newt-devel \
    numactl-devel openssl openssl-devel pciutils-devel perl perl-devel \
    perl-generators python3-devel python3-docutils rsync rust rust-src \
    systemd-boot-unsigned systemd-ukify which xmlto xz-devel zlib-devel \
    python3-requests hmaccalc dracut tpm2-tools rustfmt clippy bpftool \
    python3-jsonschema libxml2-devel swig opencsd-devel automake \
    libtool libtirpc libtirpc-devel && dnf clean all

RUN printf '[updates-archive]\n\
name=Fedora $releasever - $basearch - Updates Archive\n\
baseurl=https://fedoraproject-updates-archive.fedoraproject.org/fedora/$releasever/$basearch/\n\
enabled=1\n\
metadata_expire=6h\n\
repo_gpgcheck=0\n\
type=rpm\n\
gpgcheck=1\n\
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$releasever-$basearch\n' > /etc/yum.repos.d/fedora-updates-archive.repo
RUN dnf install -y --allow-downgrade rust-1.92.0 rust-src-1.92.0

ARG UID=1000
ARG GID=1000

RUN groupadd -g $GID -o builder && \
    useradd -m -u $UID -g $GID -o -s /bin/bash builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder && \
    chmod 0440 /etc/sudoers.d/builder
    
USER builder

WORKDIR /workspace

ENTRYPOINT [ "env" ]