# Use the official Debian base image
FROM debian:12.12
ENV DEBIAN_FRONTEND=noninteractive
ENV OPENVPN_VERSION=v2.6.15

# Install build dependencies and tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    autoconf \
    automake \
    python3-docutils \
    libtool \
    libssl-dev \
    liblzo2-dev \
    liblz4-dev \
    libpam0g-dev \
    libpkcs11-helper1-dev \
    libcap-ng-dev \
    libnl-3-dev \
    libnl-genl-3-dev \
    pkg-config \
    ca-certificates \
    net-tools \
    tcpdump \
    ethtool \
    iputils-ping \
    iproute2 \
    curl \
    vim \
    nano \
    ssh \
    sudo \
    procps \
    git \
    make \
    golang \
    iptables \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Clone and build OpenVPN from GitHub
RUN git clone https://github.com/OpenVPN/openvpn.git /opt/openvpn && \
    cd /opt/openvpn && \
    git checkout ${OPENVPN_VERSION} && \
    autoreconf -vi && \
    ./configure && \
    make -j$(nproc) && \
    make install

# Create openvpn user and group with a shell (needed for sudo)
RUN groupadd --system openvpn && \
    useradd --system --create-home --home-dir /home/openvpn --shell /bin/bash -g openvpn openvpn

# Setup sudo for openvpn user (no password required)
RUN echo "openvpn ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/openvpn && \
    chmod 0440 /etc/sudoers.d/openvpn

# Create OpenVPN configuration and log directories
RUN mkdir -p /home/openvpn/config /home/openvpn/logs && \
    chown -R openvpn:openvpn /home/openvpn

# Logging to standard output
RUN ln -sf /dev/stdout /home/openvpn/logs/openvpn.log

# Copy OpenVPN exporter
COPY --chown=openvpn:openvpn Exporter/ /home/openvpn/exporter

# Copy configuration and script files
COPY --chown=openvpn:openvpn Server/reload-config.sh /home/openvpn/reload-config.sh
COPY --chown=openvpn:openvpn Server/exporter.yml /home/openvpn/exporter.yml

# Make script executable
RUN chmod +x /home/openvpn/reload-config.sh

# # Build OpenVPN exporter as openvpn user
WORKDIR /home/openvpn/exporter
RUN go mod tidy

# # Build OpenVPN exporter as openvpn user
USER openvpn
RUN build -o openvpn-exporter .

# Use working directory
WORKDIR /home/openvpn

# Expose OpenVPN and exporter ports
EXPOSE 443/tcp 443/udp 9234/tcp

# Run reload script on container start
ENTRYPOINT ["/home/openvpn/reload-config.sh"]
