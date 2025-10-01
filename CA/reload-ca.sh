#!/bin/bash

# Define the paths
CLIENT_CONF="/home/openvpn/config/client.conf"
SERV_TCP_CONF="/home/openvpn/config/server-tcp.conf"
SERV_COMMON_CONF="/home/openvpn/config/server-common.conf"

# Change ownership of all files in config folder
sudo chown -R openvpn:openvpn /home/openvpn/config/

# Clean config and logs folders
sudo rm -rf /home/openvpn/config/*
sudo rm -rf /home/openvpn/logs/*

# Create CA cert folder
mkdir -p /home/openvpn/config/ca

# If the client config does not exist, it means we need to generate config
echo "Generating configuration files for client and server..."

# Generate CA certificate files (private key, certificate, etc.)
echo "Generating CA certificate files"
openssl genpkey -algorithm RSA -out /home/openvpn/config/ca/ca.key -pkeyopt rsa_keygen_bits:2048
openssl req -x509 -new -nodes -key /home/openvpn/config/ca/ca.key -sha256 -days 3650 -out /home/openvpn/config/ca/ca.crt -subj "/C=KSC/L=Kosice/O=Test/OU=Test/CN=OpenVPN"

# Generate certificate files required for server (private key, csr, certificate, etc.)
echo "Generating server certificate files"
openssl genpkey -algorithm RSA -out /home/openvpn/config/server.key -pkeyopt rsa_keygen_bits:2048
openssl req -new -key /home/openvpn/config/server.key -out /home/openvpn/config/server.csr -subj "/C=KSC/L=Kosice/O=Test/OU=Test/CN=cicd.openvpn.com"
openssl x509 -req -in /home/openvpn/config/server.csr -CA /home/openvpn/config/ca/ca.crt -CAkey /home/openvpn/config/ca/ca.key -CAcreateserial -out /home/openvpn/config/server.crt -days 365 -sha256

# Generate DH parameters file
echo "Generating DH parameters file for server"
openssl dhparam -out /home/openvpn/config/dh2048.pem 2048

# Generate HMAC firewall TA private key
echo "generate TA private key for HMAC firewall"
openvpn --genkey --secret /home/openvpn/config/ta.key

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
echo "dh /home/openvpn/config/dh2048.pem" >> "$SERV_COMMON_CONF"
echo "topology subnet" >> "$SERV_COMMON_CONF"
echo 'push "redirect-gateway def1"' >> "$SERV_COMMON_CONF"
echo 'push "dhcp-option DNS 1.1.1.1"' >> "$SERV_COMMON_CONF"
echo 'push "dhcp-option DNS 8.8.8.8"' >> "$SERV_COMMON_CONF"
echo "keepalive 10 120" >> "$SERV_COMMON_CONF"
echo "tls-auth /home/openvpn/config/ta.key 0" >> "$SERV_COMMON_CONF"
echo "cipher AES-256-CBC" >> "$SERV_COMMON_CONF"
echo "data-ciphers AES-128-GCM:AES-256-GCM" >> "$SERV_COMMON_CONF"
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

# Generate client related certificates (private key, csr, signed cert)
echo "Generating client certificate files"
openssl genpkey -algorithm RSA -out /home/openvpn/config/client.key -pkeyopt rsa_keygen_bits:2048
openssl req -new -key /home/openvpn/config/client.key -out /home/openvpn/config/client.csr -subj "/C=KSC/L=Kosice/O=Test/OU=Test/CN=client.cicd.openvpn.com"
openssl x509 -req -in /home/openvpn/config/client.csr -CA /home/openvpn/config/ca/ca.crt -CAkey /home/openvpn/config/ca/ca.key -CAcreateserial -out /home/openvpn/config/client.crt -days 365 -sha256

# Generate client configuration and container required parameters
echo "Generating client configuration file"
touch "$CLIENT_CONF"
echo "client" >> "$CLIENT_CONF"
echo "dev tun" >> "$CLIENT_CONF"
echo "remote cicd.openvpn.com 443 tcp" >> "$CLIENT_CONF"
echo "resolv-retry infinite" >> "$CLIENT_CONF"
echo "nobind" >> "$CLIENT_CONF"
echo "persist-key" >> "$CLIENT_CONF"
echo "persist-tun" >> "$CLIENT_CONF"
echo "<cert>" >> "$CLIENT_CONF"
cat /home/openvpn/config/client.crt >> "$CLIENT_CONF"
echo "</cert>" >> "$CLIENT_CONF"
echo "<key>" >> "$CLIENT_CONF"
cat /home/openvpn/config/client.key >> "$CLIENT_CONF"
echo "</key>" >> "$CLIENT_CONF"
echo "<ca>" >> "$CLIENT_CONF"
cat /home/openvpn/config/ca/ca.crt >> "$CLIENT_CONF"
echo "</ca>" >> "$CLIENT_CONF"
echo "key-direction 1" >> "$CLIENT_CONF"
echo "<tls-auth>" >> "$CLIENT_CONF"
cat /home/openvpn/config/ta.key >> "$CLIENT_CONF"
echo "</tls-auth>" >> "$CLIENT_CONF"
echo "cipher AES-256-CBC" >> "$CLIENT_CONF"
echo "data-ciphers AES-128-GCM:AES-256-GCM" >> "$CLIENT_CONF"
echo "data-ciphers-fallback AES-256-CBC" >> "$CLIENT_CONF"
echo "verb 3" >> "$CLIENT_CONF"

echo "Logging of client and server config files"
echo "### CLIENT CONFIG ###"
cat $CLIENT_CONF
echo "### SERVER CONFIG ###"
cat $SERV_TCP_CONF
cat $SERV_COMMON_CONF

# echo "Running endless running process ..."
# tail -f /dev/null

# Wait for all background processes to finish
wait