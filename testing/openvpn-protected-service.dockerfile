FROM debian:trixie-slim

# Install necessary tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    iputils-ping \
    iproute2 \
    ca-certificates \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create entrypoint script
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo 'echo "Starting openvpn-protected-service..."' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo 'echo "Current network configuration:"' >> /entrypoint.sh && \
    echo 'ip addr show' >> /entrypoint.sh && \
    echo 'echo ""' >> /entrypoint.sh && \
    echo 'ip route show' >> /entrypoint.sh && \
    echo 'echo ""' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo 'echo "Setting default route via 10.10.10.100..."' >> /entrypoint.sh && \
    echo 'ip route del default 2>/dev/null || true' >> /entrypoint.sh && \
    echo 'ip route add default via 10.10.10.100' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo 'echo "Updated routing table:"' >> /entrypoint.sh && \
    echo 'ip route show' >> /entrypoint.sh && \
    echo 'echo ""' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo 'echo "Testing connectivity to gateway..."' >> /entrypoint.sh && \
    echo 'ping -c 3 10.10.10.100 || echo "Gateway not reachable yet"' >> /entrypoint.sh && \
    echo 'echo ""' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo 'echo "Service is ready and running..."' >> /entrypoint.sh && \
    echo 'exec tail -f /dev/null' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]