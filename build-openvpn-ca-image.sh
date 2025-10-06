#!/bin/bash
SERVER_IMAGE_NAME='ThaseG/openvpn-generator'
CI_REGISTRY_SERVER_IMAGE="${CI_REGISTRY}/${SERVER_IMAGE_NAME}"

# Static version part
source openvpn/versions.sh

# Now you can use the variables
echo "Image Version= ${CA_IMAGE_VERSION}"
echo "OpenVPN Version= ${OPENVPN_VERSION}"
echo ""
echo "REGISTRY=${CI_REGISTRY}"
echo "IMAGE_NAME=${SERVER_IMAGE_NAME}"
echo "REPOSITORY=${CI_REGISTRY_SERVER_IMAGE}"
echo ""

# Clean up old images
echo "Removing older openvpn image builds ..."
docker rmi -f "${CI_REGISTRY_SERVER_IMAGE}:${CA_IMAGE_VERSION}"

# Build new image
echo "Building new openvpn image ..."
docker builder build \
  --build-arg http_proxy="${PROXY_EC_URL}" \
  --build-arg https_proxy="${PROXY_EC_URL}" \
  --build-arg OPENVPN_VERSION="${OPENVPN_VERSION}" \
  -t ${CI_REGISTRY_SERVER_IMAGE}:${CA_IMAGE_VERSION} \
  -f openvpn/CA/openvpn_ca.dockerfile \
  .

# Show current images
docker images

# Push to registry
echo "Pushing image to registry..."
docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"
docker push "${CI_REGISTRY_SERVER_IMAGE}:${CA_IMAGE_VERSION}"

# Clean up local image
docker rmi -f "${CI_REGISTRY_SERVER_IMAGE}:${CA_IMAGE_VERSION}"
