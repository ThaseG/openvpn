#!/bin/bash

# Static version part
source openvpn/versions.sh

GENERATOR_IMAGE_NAME='openvpn-generator:${IMAGE_VERSION}'
CLIENT_BOOKWORM_IMAGE_NAME='openvpn-bookworm:${IMAGE_VERSION}'
CLIENT_BULLSEYE_IMAGE_NAME='openvpn-bullseye:${IMAGE_VERSION}'
CLIENT_JAMMY_IMAGE_NAME='openvpn-jammy:${IMAGE_VERSION}'
CLIENT_FOCAL_IMAGE_NAME='openvpn-focal:${IMAGE_VERSION}'
SERVER_IMAGE_NAME='openvpn:${IMAGE_VERSION}'

# Now you can use the variables
echo "Image Version= ${IMAGE_VERSION}"
echo "OpenVPN Version= ${OPENVPN_VERSION}"
echo "IMAGE_NAME=${SERVER_IMAGE_NAME}"
echo ""

# Stop container if it is running
docker stop openvpn-generator
sleep 5

# Remove container if it exist
docker rm openvpn-generator

# Clean up old generator image
echo "Removing older openvpn config generator image builds ..."
docker rmi -f "${GENERATOR_IMAGE_NAME}"

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
docker network rm openvpn

# Create docker network
docker network create --subnet=192.168.200.0/24 openvpn

# Clear docker volume
docker volume rm openvpn_config

# Create docker volume
docker volume create openvpn_config

# Run container out from this image
docker run -d --name openvpn-generator -v openvpn_config:/home/openvpn/config ${OPENVPN_VERSION}
