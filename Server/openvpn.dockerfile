# Use the official Debian base image
FROM debian:12-slim
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
    sudo \
    procps \
    git \
    make \
    wget \
    iptables \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Go 1.23 manually (removed 'golang' from apt and added this)
RUN wget -q https://go.dev/dl/go1.23.5.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.23.5.linux-amd64.tar.gz && \
    rm go1.23.5.linux-amd64.tar.gz

ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/home/openvpn/go"
ENV PATH="${GOPATH}/bin:${PATH}"

# Verify Go installation
RUN go version

# Clone and build OpenVPN from GitHub
RUN git clone https://github.com/OpenVPN/openvpn.git /opt/openvpn && \
    cd /opt/openvpn && \
    git checkout ${OPENVPN_VERSION} && \
    autoreconf -vi && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    rm -rf /opt/openvpn/sample/sample-keys/*.key \
           /opt/openvpn/sample/sample-config-files/loopback-client

# Create openvpn user and group with a shell (needed for sudo)
RUN groupadd --system openvpn && \
    useradd --system --create-home --home-dir /home/openvpn --shell /bin/bash -g openvpn openvpn

# Setup sudo for openvpn user (no password required)
RUN echo "openvpn ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/openvpn && \
    chmod 0440 /etc/sudoers.d/openvpn

# Create OpenVPN configuration and log directories
RUN mkdir -p /home/openvpn/config /home/openvpn/logs /home/openvpn/exporter /home/openvpn/go && \
    chown -R openvpn:openvpn /home/openvpn

# Logging to standard output
RUN ln -sf /dev/stdout /home/openvpn/logs/openvpn.log

# Copy OpenVPN exporter
COPY --chown=openvpn:openvpn Exporter/ /home/openvpn/exporter/

# Copy configuration and script files
COPY --chown=openvpn:openvpn Server/reload-config.sh /home/openvpn/reload-config.sh
COPY --chown=openvpn:openvpn Server/exporter.yml /home/openvpn/exporter.yml

# Make script executable
RUN chmod +x /home/openvpn/reload-config.sh

# Build OpenVPN exporter as openvpn user
USER openvpn
WORKDIR /home/openvpn/exporter

# Download dependencies and build
RUN go mod download && \
    go mod verify && \
    go build -v -o openvpn-exporter .

# Use working directory
WORKDIR /home/openvpn

# Expose OpenVPN and exporter ports
EXPOSE 443/tcp 443/udp 9234/tcp

# Run reload script on container start
ENTRYPOINT ["/home/openvpn/reload-config.sh"]