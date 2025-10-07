#!/bin/bash
set -e  # Exit on error

# Define the paths
COMMON_CONF="/home/openvpn/config/server-common.conf"
TCP_CONF="/home/openvpn/config/server-tcp.conf"
UDP_CONF="/home/openvpn/config/server-udp.conf"
LOG_DIR="/home/openvpn/logs"
CONFIG_DIR="/home/openvpn/config"

# Change ownership of all files in config folder
sudo chown -R openvpn:openvpn "$CONFIG_DIR"

# Backup old logfiles before starting OpenVPN
echo "Backing up old log files..."
if [ -f "$LOG_DIR/openvpn.log" ]; then
    cp "$LOG_DIR/openvpn.log" "$LOG_DIR/openvpn.log.backup"
fi

if [ -f "$LOG_DIR/openvpn-tcp-status" ]; then
    cp "$LOG_DIR/openvpn-tcp-status" "$LOG_DIR/openvpn-tcp-status.backup"
fi

if [ -f "$LOG_DIR/openvpn-udp-status" ]; then
    cp "$LOG_DIR/openvpn-udp-status" "$LOG_DIR/openvpn-udp-status.backup"
fi

# Implement iptables rules if the config file exists
if [ -f "$CONFIG_DIR/iptables.sh" ]; then
    echo "Applying iptables rules..."
    sudo chmod +x "$CONFIG_DIR/iptables.sh"
    sudo "$CONFIG_DIR/iptables.sh"
fi

# Check if the common configuration file exists
if [ ! -f "$COMMON_CONF" ]; then
    echo "ERROR: Common configuration not found at $COMMON_CONF"
    exit 1
fi

# Array to track background PIDs
pids=()

# Start TCP instance if config exists
if [ -f "$TCP_CONF" ]; then
    echo "Starting OpenVPN with TCP configuration..."
    sudo openvpn --config "$TCP_CONF" &
    pids+=($!)
    echo "OpenVPN TCP started with PID ${pids[-1]}"
else
    echo "WARNING: TCP configuration not found at $TCP_CONF"
fi

# Start UDP instance if config exists
if [ -f "$UDP_CONF" ]; then
    echo "Starting OpenVPN with UDP configuration..."
    sudo openvpn --config "$UDP_CONF" &
    pids+=($!)
    echo "OpenVPN UDP started with PID ${pids[-1]}"
else
    echo "WARNING: UDP configuration not found at $UDP_CONF"
fi

# Check if at least one OpenVPN instance started
if [ ${#pids[@]} -eq 0 ]; then
    echo "ERROR: No OpenVPN instances started. No TCP or UDP configuration found."
    exit 1
fi

# Give OpenVPN a moment to start
sleep 2

# Start the openvpn-exporter (likely doesn't need sudo)
if [ -f /home/openvpn/exporter/openvpn-exporter ]; then
    echo "Starting OpenVPN Exporter..."
    /home/openvpn/exporter/openvpn-exporter --config.file=/home/openvpn/exporter.yml &
    pids+=($!)
    echo "OpenVPN exporter started with PID ${pids[-1]}"
else
    echo "WARNING: Exporter binary not found"
fi

# Function to handle shutdown gracefully
shutdown() {
    echo "Shutting down gracefully..."
    for pid in "${pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            echo "Stopping process $pid"
            sudo kill "$pid"
        fi
    done
    exit 0
}

# Trap SIGTERM and SIGINT for graceful shutdown
trap shutdown SIGTERM SIGINT

echo "All services started. Waiting for processes..."
# Wait for all background processes
wait
