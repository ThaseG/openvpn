# Use the official Debian base image
FROM ubuntu:jammy

# Set environment variables to avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update package list and install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    openvpn \
    net-tools \
    tcpdump \
    ethtool \
    iputils-ping \
    iproute2 \
    curl \
    wget \
    vim \
    nano \
    ssh \
    sudo \
    iptables \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for running OpenVPN
RUN groupadd openvpn
RUN useradd -m -s /bin/bash openvpn -g openvpn

# Ensure /dev/net/tun exists
RUN mkdir -p /dev/net && \
    mknod /dev/net/tun c 10 200 && \
    chmod 666 /dev/net/tun

# Allow the openvpn user to execute sudo commands without password
RUN echo 'openvpn ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Switch to the openvpn user
USER openvpn

# Create directory for OpenVPN configuration & logs
RUN mkdir -p /home/openvpn/config
RUN mkdir -p /home/openvpn/logs

# Set the working directory
WORKDIR /home/openvpn

# Send logs from openvpn to stdout
RUN ln -sf /dev/stdout /home/openvpn/logs/openvpn-client.log

# Copy the reload script to the container
COPY --chown=openvpn:openvpn Testing/reload-client-jammy.sh /home/openvpn/reload-client-jammy.sh

# Ensure the script is executable
RUN chmod +x /home/openvpn/reload-client-jammy.sh

# Set the entrypoint to the script
ENTRYPOINT ["/home/openvpn/reload-client-jammy.sh"]
