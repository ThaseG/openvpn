#!/bin/bash
CLIENTS_IMAGE_NAME='ThaseG/openvpn-clients'
CI_REGISTRY_CLIENTS_IMAGE="${CI_REGISTRY}/${CLIENTS_IMAGE_NAME}"

# Static version part
source openvpn/versions.sh

# Iterate within CLIENT_IMAGE_VERSIONS where IMAGE_VERSION will be iterator variable
for IMAGE_VERSION in "${CLIENT_IMAGE_VERSIONS[@]}"; do

    # Now you can use the variables
    echo "Image Version= ${IMAGE_VERSION}"
    echo "OpenVPN Version= ${OPENVPN_VERSION}"
    echo ""
    echo "REGISTRY=${CI_REGISTRY}"
    echo "IMAGE_NAME=${CLIENTS_IMAGE_NAME}"
    echo "REPOSITORY=${CI_REGISTRY_CLIENTS_IMAGE}"
    echo ""
    
    # Clean up old images
    echo "Removing older openvpn client image builds ..."
    docker rmi -f "${CI_REGISTRY_CLIENTS_IMAGE}:${IMAGE_VERSION}" 2>/dev/null || true
    
    # Build new image
    echo "Building new openvpn client image for ${IMAGE_VERSION}..."
    docker builder build \
      --build-arg http_proxy="${PROXY_EC_URL}" \
      --build-arg https_proxy="${PROXY_EC_URL}" \
      --build-arg OPENVPN_VERSION="${OPENVPN_VERSION}" \
      -t ${CI_REGISTRY_CLIENTS_IMAGE}:${IMAGE_VERSION} \
      -f openvpn/Clients/openvpn_client_${IMAGE_VERSION}.dockerfile \
      .
    
    # Show current images
    docker images
    
    # Push to registry
    echo "Pushing image to registry..."
    docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"
    docker push "${CI_REGISTRY_CLIENTS_IMAGE}:${IMAGE_VERSION}"
    
    # Clean up local image
    docker rmi -f "${CI_REGISTRY_CLIENTS_IMAGE}:${IMAGE_VERSION}"

done

echo "All clients builds completed!"
