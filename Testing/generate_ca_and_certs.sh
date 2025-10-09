#!/bin/bash

# OpenVPN Certificate Generation Script with Curve25519 (Ed25519)
# Compliant with: AES-256-GCM, SHA256, Curve25519/X25519

# Load centralized variables
source ../versions.sh

# Change ownership of all files in config folder
sudo chown -R openvpn:openvpn /home/openvpn/config/

# Clean config and logs folders
sudo rm -rf /home/openvpn/config/*

# Create CA cert folder
mkdir -p /home/openvpn/config/ca

# Generate CA certificate files using Ed25519 (Curve25519)
echo "Generating CA certificate files with Ed25519 (Curve25519)"
openssl genpkey -algorithm ED25519 -out /home/openvpn/config/ca/ca.key
openssl req -x509 -new -key /home/openvpn/config/ca/ca.key -days 3650 \
    -out /home/openvpn/config/ca/ca.crt \
    -subj "/C=SK/L=Kosice/O=Test/OU=Test/CN=OpenVPN"

# Generate server certificate files using Ed25519 (Curve25519)
echo "Generating server certificate files with Ed25519 (Curve25519)"
openssl genpkey -algorithm ED25519 -out /home/openvpn/config/server.key
openssl req -new -key /home/openvpn/config/server.key \
    -out /home/openvpn/config/server.csr \
    -subj "/C=SK/L=Kosice/O=Test/OU=Test/CN=cicd.openvpn.com"
openssl x509 -req -in /home/openvpn/config/server.csr \
    -CA /home/openvpn/config/ca/ca.crt \
    -CAkey /home/openvpn/config/ca/ca.key \
    -CAcreateserial \
    -out /home/openvpn/config/server.crt \
    -days 365

# Generate client private keys using Ed25519 (Curve25519)
echo "Generating client private keys with Ed25519 (Curve25519)"
for client in "${CLIENT_IMAGE_VERSIONS[@]}"; do
    openssl genpkey -algorithm ED25519 -out /home/openvpn/config/${client}.key
    echo "✓ Generated private key for ${client}"
done

# Generate client CSRs
echo "Generating client CSRs"
for client in "${CLIENT_IMAGE_VERSIONS[@]}"; do
    openssl req -new -key /home/openvpn/config/${client}.key \
        -out /home/openvpn/config/${client}.csr \
        -subj "/C=SK/L=Kosice/O=Test/OU=Test/CN=${client}.openvpn.com"
    echo "✓ Generated CSR for ${client}"
done

# Sign client CSRs and generate certificates
echo "Signing client CSRs and generating certificates"
for client in "${CLIENT_IMAGE_VERSIONS[@]}"; do
    openssl x509 -req -in /home/openvpn/config/${client}.csr \
        -CA /home/openvpn/config/ca/ca.crt \
        -CAkey /home/openvpn/config/ca/ca.key \
        -CAcreateserial \
        -out /home/openvpn/config/${client}.crt \
        -days 365
    echo "✓ Generated certificate for ${client}"
done

# Note: DH parameters are NOT needed when using ECC/ECDH
echo "Skipping DH parameters generation (not needed with ECDH)"

# Generate TLS-Crypt key for HMAC firewall
echo "Generating TLS-Crypt key for HMAC firewall"
openvpn --genkey secret /home/openvpn/config/ta.key

# Show generated files
echo "####"
echo "ls -lah /home/openvpn/config/ca/"
ls -lah /home/openvpn/config/ca/
echo "####"
echo "ls -lah /home/openvpn/config/"
ls -lah /home/openvpn/config/

# Verify certificate details
echo "####"
echo "Verifying CA certificate uses Ed25519:"
openssl x509 -in /home/openvpn/config/ca/ca.crt -text -noout | grep "Public Key Algorithm"
openssl x509 -in /home/openvpn/config/ca/ca.crt -text -noout | grep "ED25519"
echo "####"
echo "Verifying server certificate uses Ed25519:"
openssl x509 -in /home/openvpn/config/server.crt -text -noout | grep "Public Key Algorithm"
openssl x509 -in /home/openvpn/config/server.crt -text -noout | grep "ED25519"

# Wait for all background processes to finish
wait

echo "####"
echo "Certificate generation complete!"
echo "All certificates are using Ed25519 (Curve25519)"
echo "Generated certificates for CLIENT_IMAGE_VERSIONS: ${CLIENT_IMAGE_VERSIONS[*]}"
echo "Use 'ecdh-curve X25519' in your OpenVPN config for key exchange"