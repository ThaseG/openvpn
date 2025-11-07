#!/bin/bash

# Making sure scripts exist and are executable
chmod +x generate_ca_and_certs.sh

# Generate certificates
./generate_ca_and_certs.sh

# Generate server configuration
chmod +x generate_server_config.sh
./generate_server_config.sh

# Generate server configuration
chmod +x generate_client_config.sh
./generate_client_config.sh

# Wait for all background processes to finish
wait