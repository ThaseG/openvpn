#!/bin/bash
# Define the array of client configuration paths
CLIENT_CONFS=(
    "bookworm"
    "bullseye"
    "jammy"
    "focal"
)

# Loop through each client configuration
for CLIENT_NAME in "${CLIENT_CONFS[@]}"; do
    CLIENT_CONF="/home/openvpn/config/client-${CLIENT_NAME}.conf"
    
    echo "Generating client configuration file: $CLIENT_CONF"
    
    # Create/truncate the file
    > "$CLIENT_CONF"
    
    # Generate client configuration
    cat >> "$CLIENT_CONF" << 'EOF'
client
dev tun
remote cicd.openvpn.com 443 tcp
resolv-retry infinite
nobind
persist-key
persist-tun
EOF
    
    echo "<cert>" >> "$CLIENT_CONF"
    cat "/home/openvpn/config/${CLIENT_NAME}.crt" >> "$CLIENT_CONF"
    echo "</cert>" >> "$CLIENT_CONF"
    
    echo "<key>" >> "$CLIENT_CONF"
    cat "/home/openvpn/config/${CLIENT_NAME}.key" >> "$CLIENT_CONF"
    echo "</key>" >> "$CLIENT_CONF"
    
    echo "<ca>" >> "$CLIENT_CONF"
    cat /home/openvpn/config/ca/ca.crt >> "$CLIENT_CONF"
    echo "</ca>" >> "$CLIENT_CONF"
    
    cat >> "$CLIENT_CONF" << 'EOF'
key-direction 1
<tls-auth>
EOF
    cat /home/openvpn/config/ta.key >> "$CLIENT_CONF"
    cat >> "$CLIENT_CONF" << 'EOF'
</tls-auth>
cipher AES-256-CBC
data-ciphers AES-128-GCM:AES-256-GCM
data-ciphers-fallback AES-256-CBC
verb 3
EOF
    
    echo "### CLIENT CONFIG: $CLIENT_CONF ###"
    cat "$CLIENT_CONF"
    echo ""
done

echo "All client configurations generated successfully"
wait
