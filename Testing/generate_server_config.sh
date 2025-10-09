#!/bin/bash

# Define the paths
SERV_TCP_CONF="/home/openvpn/config/server-tcp.conf"
SERV_COMMON_CONF="/home/openvpn/config/server-common.conf"

echo "Generating configuration files for server..."

# Generate server configuration files (server-tcp.conf and server-common.conf)
echo "Generating server TCP config"
touch "$SERV_TCP_CONF"
echo "proto tcp" >> "$SERV_TCP_CONF"
echo "server 10.0.0.0 255.255.255.0" >> "$SERV_TCP_CONF"
echo "link-mtu 1500" >> "$SERV_TCP_CONF"
echo "status /home/openvpn/logs/openvpn-tcp-status" >> "$SERV_TCP_CONF"
echo "config /home/openvpn/config/server-common.conf" >> "$SERV_TCP_CONF"
echo "tcp-nodelay" >> "$SERV_TCP_CONF"
echo "txqueuelen 15000" >> "$SERV_TCP_CONF"
echo "tcp-queue-limit 256" >> "$SERV_TCP_CONF"

echo "Generating server common config"
touch "$SERV_COMMON_CONF"
echo "port 443" >> "$SERV_COMMON_CONF"
echo "dev tun" >> "$SERV_COMMON_CONF"
echo "ca /home/openvpn/config/ca/ca.crt" >> "$SERV_COMMON_CONF"
echo "cert /home/openvpn/config/server.crt" >> "$SERV_COMMON_CONF"
echo "key /home/openvpn/config/server.key" >> "$SERV_COMMON_CONF"
echo "tls-version-min 1.3" >> "$SERV_COMMON_CONF"
echo "tls-version-max 1.3" >> "$SERV_COMMON_CONF"
echo "ecdh-curve X25519" >> "$SERV_COMMON_CONF"
echo "dh none" >> "$SERV_COMMON_CONF"
# echo "dh /home/openvpn/config/dh2048.pem" >> "$SERV_COMMON_CONF"
echo "topology subnet" >> "$SERV_COMMON_CONF"
echo 'push "redirect-gateway def1"' >> "$SERV_COMMON_CONF"
echo 'push "dhcp-option DNS 1.1.1.1"' >> "$SERV_COMMON_CONF"
echo 'push "dhcp-option DNS 8.8.8.8"' >> "$SERV_COMMON_CONF"
echo "keepalive 10 120" >> "$SERV_COMMON_CONF"
echo "tls-auth /home/openvpn/config/ta.key 0" >> "$SERV_COMMON_CONF"
echo "cipher AES-256-GCM" >> "$SERV_COMMON_CONF"
echo "data-ciphers AES-256-GCM" >> "$SERV_COMMON_CONF"
echo "data-ciphers-fallback AES-256-CBC" >> "$SERV_COMMON_CONF"
echo "max-clients 100" >> "$SERV_COMMON_CONF"
echo "user openvpn" >> "$SERV_COMMON_CONF"
echo "group openvpn" >> "$SERV_COMMON_CONF"
echo "persist-key" >> "$SERV_COMMON_CONF"
echo "persist-tun" >> "$SERV_COMMON_CONF"
echo "log         /home/openvpn/logs/openvpn.log" >> "$SERV_COMMON_CONF"
echo "log-append  /home/openvpn/logs/openvpn.log" >> "$SERV_COMMON_CONF"
echo "status-version 3" >> "$SERV_COMMON_CONF"
echo "push-peer-info" >> "$SERV_COMMON_CONF"
echo "verb 4" >> "$SERV_COMMON_CONF"
echo "reneg-sec 14400" >> "$SERV_COMMON_CONF"

# Make some logging if the generation went well
echo "Logging of client and server config files"
echo "### SERVER CONFIG ###"
cat $SERV_TCP_CONF
cat $SERV_COMMON_CONF

# Wait for all background processes to finish
wait