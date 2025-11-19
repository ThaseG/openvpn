# ============================================
# Stage 1: Build OpenVPN
# ============================================

FROM debian:12-slim AS openvpn-builder

ENV DEBIAN_FRONTEND=noninteractive
ENV OPENVPN_VERSION=v2.6.16

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
    git \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Build OpenVPN
RUN git clone https://github.com/OpenVPN/openvpn.git /opt/openvpn && \
    cd /opt/openvpn && \
    git checkout ${OPENVPN_VERSION} && \
    autoreconf -vi && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    rm -rf /opt/openvpn/sample/sample-keys/*.key \
           /opt/openvpn/sample/sample-config-files/loopback-client

# ============================================
# Stage 2: Build Go Exporter
# ============================================

FROM debian:12-slim AS go-builder

ENV DEBIAN_FRONTEND=noninteractive
ENV GO_VERSION=1.25.4
ENV GOPATH=/go
ENV PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

WORKDIR /build

# Install dependencies and Go
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    wget \
    && wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz \
    && rm go${GO_VERSION}.linux-amd64.tar.gz \
    && apt-get remove -y wget \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Clone and build exporter
RUN git clone https://github.com/ThaseG/openvpn-exporter /build && \
    go mod tidy && \
    go mod download && \
    go mod verify && \
    CGO_ENABLED=0 GOOS=linux go build \
    -a -installsuffix cgo \
    -ldflags="-w -s" \
    -o openvpn-exporter .

# ============================================
# Stage 3: Final Runtime Image
# ============================================

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3t64 \
    liblzo2-2 \
    liblz4-1 \
    libpam0g \
    libpkcs11-helper1 \
    libcap-ng0 \
    libnl-3-200 \
    libnl-genl-3-200 \
    iproute2 \
    curl \
    vim \
    openssl \
    sudo \
    iptables \
    && apt-get upgrade -y \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create openvpn user and group
RUN groupadd --system openvpn && \
    useradd --system --create-home --home-dir /home/openvpn --shell /bin/bash -g openvpn openvpn

# Setup sudo
RUN echo "openvpn ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/openvpn && \
    chmod 0440 /etc/sudoers.d/openvpn

# Create directories
RUN mkdir -p /home/openvpn/config /home/openvpn/logs /home/openvpn/exporter && \
    chown -R openvpn:openvpn /home/openvpn

# Copy OpenVPN binary and necessary files from builder
COPY --from=openvpn-builder /usr/local/sbin/openvpn /usr/local/sbin/openvpn
COPY --from=openvpn-builder /opt/openvpn/sample /opt/openvpn/sample

# Copy Go exporter binary from builder
COPY --from=go-builder /build/openvpn-exporter /home/openvpn/exporter/openvpn-exporter

# Link logs to stdout
RUN ln -sf /dev/stdout /home/openvpn/logs/openvpn.log

# Copy configuration files
COPY --chown=openvpn:openvpn server/reload-config.sh /home/openvpn/reload-config.sh
COPY --chown=openvpn:openvpn server/exporter.yml /home/openvpn/exporter.yml
RUN chmod +x /home/openvpn/reload-config.sh

WORKDIR /home/openvpn

# Expose ports
EXPOSE 443/tcp 443/udp 9234/tcp

USER openvpn

ENTRYPOINT ["/home/openvpn/reload-config.sh"]