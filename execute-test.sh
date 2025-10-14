#!/bin/bash

# Static version part
source versions.sh

GENERATOR_IMAGE_NAME="openvpn-generator:${IMAGE_VERSION}"
CLIENT_BOOKWORM_IMAGE_NAME="openvpn-bookworm:${IMAGE_VERSION}"
CLIENT_BULLSEYE_IMAGE_NAME="openvpn-bullseye:${IMAGE_VERSION}"
CLIENT_JAMMY_IMAGE_NAME="openvpn-jammy:${IMAGE_VERSION}"
CLIENT_FOCAL_IMAGE_NAME="openvpn-focal:${IMAGE_VERSION}"
SERVER_IMAGE_NAME="openvpn:${IMAGE_VERSION}"

# Now you can use the variables
echo "Image Version=${IMAGE_VERSION}"
echo "OpenVPN Version=${OPENVPN_VERSION}"
echo "IMAGE_NAME=${SERVER_IMAGE_NAME}"
echo ""

# Stop openvpn-generator if running and wait for it to stop
if docker ps --filter "name=openvpn-generator" --format "{{.Names}}" | grep -q "openvpn-generator"; then
    echo "Stopping openvpn-generator container..."
    docker stop openvpn-generator
    echo "Waiting for openvpn-generator to stop..."
    while docker ps --filter "name=openvpn-generator" --format "{{.Names}}" | grep -q "openvpn-generator"; do
        sleep 1
    done
    echo "openvpn-generator stopped"
else
    echo "Container openvpn-generator is not running, skipping..."
fi

# Stop openvpn-server if running and wait for it to stop
if docker ps --filter "name=openvpn-server" --format "{{.Names}}" | grep -q "^openvpn-server"; then
    echo "Stopping openvpn-server container..."
    docker stop openvpn-server
    echo "Waiting for openvpn-server to stop..."
    while docker ps --filter "name=openvpn-server" --format "{{.Names}}" | grep -q "^openvpn-server"; do
        sleep 1
    done
    echo "openvpn-server stopped"
else
    echo "Container openvpn-server is not running, skipping..."
fi

# Stop openvpn client-bookworm if running and wait for it to stop
if docker ps --filter "name=client-bookworm" --format "{{.Names}}" | grep -q "^client-bookworm"; then
    echo "Stopping client-bookworm container..."
    docker stop client-bookworm
    echo "Waiting for client-bookwormto stop..."
    while docker ps --filter "name=client-bookworm" --format "{{.Names}}" | grep -q "^client-bookworm"; do
        sleep 1
    done
    echo "client-bookworm stopped"
else
    echo "Container client-bookworm is not running, skipping..."
fi

# Remove containers if they exist
if docker ps -a --format '{{.Names}}' | grep -q '^openvpn-generator$'; then
    docker rm openvpn-generator
fi

if docker ps -a --format '{{.Names}}' | grep -q '^openvpn-server$'; then
    docker rm openvpn-server
fi

if docker ps -a --format '{{.Names}}' | grep -q '^client-bookworm$'; then
    docker rm client-bookworm
fi

# Clean up old generator image
echo "Removing older openvpn config generator image builds ..."
docker rmi -f "${GENERATOR_IMAGE_NAME}" 2>/dev/null || true
docker rmi -f "${SERVER_IMAGE_NAME}" 2>/dev/null || true
docker rmi -f "${CLIENT_BOOKWORM_IMAGE_NAME}" 2>/dev/null || true

# Build new generator image
echo "Building new openvpn generator image ..."
docker builder build \
  --build-arg OPENVPN_VERSION="${OPENVPN_VERSION}" \
  -t ${GENERATOR_IMAGE_NAME} \
  -f Testing/openvpn_generator.dockerfile \
  .

# Show current images
docker images

# Clean docker network
docker network rm external 2>/dev/null || true
docker network rm internal 2>/dev/null || true

# Create docker network
docker network create --subnet=192.168.200.0/24 external
docker network create --subnet=10.10.10.0/24 internal

# Delete docker volume
docker volume rm openvpn_config 2>/dev/null || true

# Create docker volume
docker volume create openvpn_config

# Run container out from this image
docker run -d --name openvpn-generator -v openvpn_config:/home/openvpn/config openvpn-generator:v1.0.0

# Building openvpn server image
echo "Building new openvpn server image ..."
docker builder build \
  -t ${SERVER_IMAGE_NAME} \
  -f Server/openvpn.dockerfile \
  .

# Wait until generate config will end
docker wait openvpn-generator 2>/dev/null || true

# Building openvpn client-bookworm image
echo "Building openvpn client-bookworm image ..."
docker builder build \
  -t ${CLIENT_BOOKWORM_IMAGE_NAME} \
  -f Testing/openvpn_client_bookworm.dockerfile \
  .

# Run container out from this image
docker run -d --name openvpn-server \
  -v openvpn_config:/home/openvpn/config \
  -p 192.168.200.100:443:443/tcp \
  -p 192.168.200.100:443:443/udp \
  -p 192.168.200.100:443:9234/tcp \
  --network=external \
  --cap-add NET_ADMIN \
  --device /dev/net/tun:/dev/net/tun \
  ${SERVER_IMAGE_NAME}

docker network connect --ip 10.10.10.100 internal openvpn-server

# Run container out from this image
docker run -d --name client-bookworm \
  -v openvpn_config:/home/openvpn/config \
  --network=internal \
  --cap-add NET_ADMIN \
  --device /dev/net/tun:/dev/net/tun \
  ${CLIENT_BOOKWORM_IMAGE_NAME}