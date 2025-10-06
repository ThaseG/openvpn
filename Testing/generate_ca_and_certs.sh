#!/bin/bash

# Change ownership of all files in config folder
sudo chown -R openvpn:openvpn /home/openvpn/config/

# Clean config and logs folders
sudo rm -rf /home/openvpn/config/*

# Create CA cert folder
mkdir -p /home/openvpn/config/ca

# Generate CA certificate files (private key, certificate, etc.)
echo "Generating CA certificate files"
openssl genpkey -algorithm RSA -out /home/openvpn/config/ca/ca.key -pkeyopt rsa_keygen_bits:2048
openssl req -x509 -new -nodes -key /home/openvpn/config/ca/ca.key -sha256 -days 3650 -out /home/openvpn/config/ca/ca.crt -subj "/C=KSC/L=Kosice/O=Test/OU=Test/CN=OpenVPN"

# Generate certificate files required for server (private key, csr, certificate, etc.)
echo "Generating server certificate files"
openssl genpkey -algorithm RSA -out /home/openvpn/config/server.key -pkeyopt rsa_keygen_bits:2048
openssl req -new -key /home/openvpn/config/server.key -out /home/openvpn/config/server.csr -subj "/C=KSC/L=Kosice/O=Test/OU=Test/CN=cicd.openvpn.com"
openssl x509 -req -in /home/openvpn/config/server.csr -CA /home/openvpn/config/ca/ca.crt -CAkey /home/openvpn/config/ca/ca.key -CAcreateserial -out /home/openvpn/config/server.crt -days 365 -sha256

# Generate clients related certificates (private keys, csrs, signed certs)
echo "Generating clients private keys"
openssl genpkey -algorithm RSA -out /home/openvpn/config/bookworm.key -pkeyopt rsa_keygen_bits:2048
openssl genpkey -algorithm RSA -out /home/openvpn/config/bullseye.key -pkeyopt rsa_keygen_bits:2048
openssl genpkey -algorithm RSA -out /home/openvpn/config/focal.key -pkeyopt rsa_keygen_bits:2048
openssl genpkey -algorithm RSA -out /home/openvpn/config/jammy.key -pkeyopt rsa_keygen_bits:2048
echo "Generating clients CSRs"
openssl req -new -key /home/openvpn/config/bookworm.key -out /home/openvpn/config/bookworm.csr -subj "/C=KSC/L=Kosice/O=Test/OU=Test/CN=bookworm.openvpn.com"
openssl req -new -key /home/openvpn/config/bullseye.key -out /home/openvpn/config/bullseye.csr -subj "/C=KSC/L=Kosice/O=Test/OU=Test/CN=bullseye.openvpn.com"
openssl req -new -key /home/openvpn/config/focal.key -out /home/openvpn/config/focal.csr -subj "/C=KSC/L=Kosice/O=Test/OU=Test/CN=focal.openvpn.com"
openssl req -new -key /home/openvpn/config/jammy.key -out /home/openvpn/config/jammy.csr -subj "/C=KSC/L=Kosice/O=Test/OU=Test/CN=jammy.openvpn.com"
echo "Signing clients CSRs and generating certificates"
openssl x509 -req -in /home/openvpn/config/bookworm.csr -CA /home/openvpn/config/ca/ca.crt -CAkey /home/openvpn/config/ca/ca.key -CAcreateserial -out /home/openvpn/config/bookworm.crt -days 365 -sha256
openssl x509 -req -in /home/openvpn/config/bullseye.csr -CA /home/openvpn/config/ca/ca.crt -CAkey /home/openvpn/config/ca/ca.key -CAcreateserial -out /home/openvpn/config/bullseye.crt -days 365 -sha256
openssl x509 -req -in /home/openvpn/config/focal.csr -CA /home/openvpn/config/ca/ca.crt -CAkey /home/openvpn/config/ca/ca.key -CAcreateserial -out /home/openvpn/config/focal.crt -days 365 -sha256
openssl x509 -req -in /home/openvpn/config/jammy.csr -CA /home/openvpn/config/ca/ca.crt -CAkey /home/openvpn/config/ca/ca.key -CAcreateserial -out /home/openvpn/config/jammy.crt -days 365 -sha256

# Generate DH parameters file
echo "Generating DH parameters file for server"
openssl dhparam -out /home/openvpn/config/dh2048.pem 2048

# Generate HMAC firewall TA private key
echo "generate TA private key for HMAC firewall"
openvpn --genkey --secret /home/openvpn/config/ta.key

# Show folders
echo "####"
echo "ls -lah /home/openvpn/config/ca/"
ls -lah /home/openvpn/config/ca/
echo "####"
echo "ls -lah /home/openvpn/config/"
ls -lah /home/openvpn/config/

# Wait for all background processes to finish
wait