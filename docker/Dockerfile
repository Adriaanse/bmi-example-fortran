FROM almalinux:8

# Install basic tools + gcc (required by ifx as backend)
RUN dnf install -y wget curl git gcc

# Import Intel GPG key
RUN rpm --import https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB

# Add Intel oneAPI repo
RUN echo '[oneAPI]' > /etc/yum.repos.d/intel-oneapi.repo && \
    echo 'name=Intel® oneAPI repository' >> /etc/yum.repos.d/intel-oneapi.repo && \
    echo 'baseurl=https://yum.repos.intel.com/oneapi' >> /etc/yum.repos.d/intel-oneapi.repo && \
    echo 'enabled=1' >> /etc/yum.repos.d/intel-oneapi.repo && \
    echo 'gpgcheck=1' >> /etc/yum.repos.d/intel-oneapi.repo && \
    echo 'repo_gpgcheck=1' >> /etc/yum.repos.d/intel-oneapi.repo && \
    echo 'gpgkey=https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB' >> /etc/yum.repos.d/intel-oneapi.repo

# Install Intel Fortran compiler 2025.2 explicitly
RUN dnf install -y intel-oneapi-compiler-fortran-2025.2.0

# Set up environment permanently
RUN echo "source /opt/intel/oneapi/setvars.sh --force" >> /etc/bashrc

CMD ["/bin/bash"]
