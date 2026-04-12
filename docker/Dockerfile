FROM almalinux:8

# Install basic tools + gcc (required by ifx as backend)
RUN dnf install -y wget curl git gcc

# Import Intel GPG key
RUN rpm --import https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB

# Add Intel oneAPI repo
RUN tee /etc/yum.repos.d/intel-oneapi.repo << EOF
[oneAPI]
name=Intel® oneAPI repository
baseurl=https://yum.repos.intel.com/oneapi
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
EOF

# Install Intel Fortran compiler 2025.2 explicitly
RUN dnf install -y intel-oneapi-compiler-fortran-2025.2.0

# Set up environment permanently
RUN echo "source /opt/intel/oneapi/setvars.sh --force" >> /etc/bashrc

CMD ["/bin/bash"]