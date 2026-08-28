#!/bin/bash

BRIDGE_NAME="ospf-br-area1"

if ! ip link show "$BRIDGE_NAME" &>/dev/null; then
  echo "[deploy.sh] Bridge $BRIDGE_NAME non trovato, lo creo..."
  sudo ip link add "$BRIDGE_NAME" type bridge
  sudo ip link set "$BRIDGE_NAME" up
else
  echo "[deploy.sh] Bridge $BRIDGE_NAME già presente, salto la creazione."
fi

containerlab deploy -t "../cisco-iol.clab.yml"
