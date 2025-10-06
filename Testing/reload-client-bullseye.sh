#!/bin/bash

# Define the paths
CLIENT_CONF="/home/openvpn/config/client-bullseye.conf"
CLIENT_SCRIPT="/home/openvpn/config/client-bullseye.sh"

# Change ownership of all files in config folder
sudo chown -R openvpn:openvpn /home/openvpn/config/

# Check if script for client config exist
if [ -f "$CLIENT_SCRIPT" ]; then
    # Just for sure add execution parameter
    sudo chmod +x /home/openvpn/config/client.sh
    # Now execute it
    sudo /home/openvpn/config/client.sh

# If there is no client script, then executing client config
else
    # If the client config exists:
    # Add DNS entry for our domain
    sudo bash -c "echo '192.168.200.100 cicd.openvpn.com' >> /etc/hosts"
    # Start client with generated configuration
    echo "Starting client with generated configuration ..."
    # We run with sudo, because without this openvpn won't have rights to utilize /dev/net/tun
    sudo openvpn --config "$CLIENT_CONF" &
    # We also check curl to see exporter statistics
    curl -vvv http://cicd.openvpn.com:9234/metrics
fi

# Wait for all background processes to finish
wait
