#!/bin/bash

BRIDGE_NAME="${1:?Usage: $0 <bridge-name>}"

if ! ip link show "$BRIDGE_NAME" &>/dev/null; then
  echo "Bridge $BRIDGE_NAME not found, creating it..."
  sudo ip link add "$BRIDGE_NAME" type bridge
  sudo ip link set "$BRIDGE_NAME" up
else
  echo "Bridge $BRIDGE_NAME already present, skipping creation."
fi
