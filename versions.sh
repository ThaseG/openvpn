#!/bin/bash
IMAGE_VERSION='v1.0.2'
OPENVPN_VERSION='v2.6.17' # For upgrade, please update also in server/openvpn.dockerfile
CLIENT_IMAGE_VERSIONS=("bullseye" "bookworm" "focal" "jammy")