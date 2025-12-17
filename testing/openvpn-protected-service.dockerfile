FROM debian:trixie-slim

# Install necessary tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    iputils-ping \
    iproute2 \
    ca-certificates \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create entrypoint script inline
RUN cat > /entrypoint.sh <<'EOF'
#!/bin/bash
set -e

echo "Starting openvpn-protected-service..."

# Display current network configuration
echo "Current network configuration:"
ip addr show
echo ""
ip route show
echo ""

# Add default route via 10.10.10.100
echo "Setting default route via 10.10.10.100..."
ip route del default 2>/dev/null || true
ip route add default via 10.10.10.100

echo "Updated routing table:"
ip route show
echo ""

# Test connectivity
echo "Testing connectivity to gateway..."
ping -c 3 10.10.10.100 || echo "Gateway not reachable yet"
echo ""

echo "Service is ready and running..."

# Keep container running
exec tail -f /dev/null
EOF

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]