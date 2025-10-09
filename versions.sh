#!/bin/bash
IMAGE_VERSION='v1.0.0'
OPENVPN_VERSION='v2.6.15' # For upgrade, please update also in Server/openvpn.dockerfile
CLIENT_IMAGE_VERSIONS=("bullseye" "bookworm" "focal" "jammy")