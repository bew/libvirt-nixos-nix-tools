#!/bin/bash

set -e

function info
{
  if [[ $# != 0 ]]; then
    echo "---" "$@"
  else
    echo
  fi
}

function virsh-list-find-network
{
  virsh net-list --all | grep "$NETWORK_NAME"
}

#----------------------------------------

if [[ $# != 2 ]]; then
  echo "Usage: $0 <network-name> <network-definition-path>"
  exit 1
fi

NETWORK_NAME="$1"
NETWORK_DEFINITION_PATH="$2"

info "Objective: Recreate network '$NETWORK_NAME' with definition '$NETWORK_DEFINITION_PATH'"
info

# stop/destroy/undefine existing network
if virsh-list-find-network >/dev/null; then
  if ! virsh-list-find-network | grep "inactive" >/dev/null; then
    info "Network '$NETWORK_NAME' is active, destroying it..."
    virsh net-destroy "$NETWORK_NAME"
  fi
  info "Network '$NETWORK_NAME' is defined, undefining it..."
  virsh net-undefine "$NETWORK_NAME"
fi
info

# check network definition is named correctly
info "Checking network definition's name"
if ! grep "<name>$NETWORK_NAME</name>" "$NETWORK_DEFINITION_PATH" >/dev/null; then
  echo "Error: Network definition '$NETWORK_DEFINITION_PATH' does not define network named '$NETWORK_NAME'"
  false
fi
info


# register network with new xml
info "Registering new xml network '$NETWORK_DEFINITION_PATH'..."
virsh net-define "$NETWORK_DEFINITION_PATH"
info

# start network
info "Starting network '$NETWORK_NAME'..."
virsh net-start "$NETWORK_NAME"
info

# done!
info "Yay \\o/"
