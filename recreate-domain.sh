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

function virsh-list-find-domain
{
  virsh list --all | grep "$DOMAIN_NAME"
}

#----------------------------------------

if [[ $# != 2 ]]; then
  echo "Usage: $0 <domain-name> <domain-definition-path>"
  exit 1
fi

DOMAIN_NAME="$1"
DOMAIN_DEFINITION_PATH="$2"

info "Objective: Recreate domain '$DOMAIN_NAME' with definition '$DOMAIN_DEFINITION_PATH'"
info

# stop/destroy/undefine existing domain
if virsh-list-find-domain >/dev/null; then
  if ! virsh-list-find-domain | grep "shut off" >/dev/null; then
    info "Domain '$DOMAIN_NAME' is running, destroying it..."
    virsh destroy "$DOMAIN_NAME"
  fi
  info "Domain '$DOMAIN_NAME' is defined, undefining it..."
  virsh undefine "$DOMAIN_NAME"
fi
info

# check domain definition is named correctly
info "Checking domain definition's name"
if ! grep "<name>$DOMAIN_NAME</name>" "$DOMAIN_DEFINITION_PATH" >/dev/null; then
  echo "Error: Domain definition '$DOMAIN_DEFINITION_PATH' does not define domain named '$DOMAIN_NAME'"
  false
fi
info


# register domain with new xml
info "Registering new xml domain '$DOMAIN_DEFINITION_PATH'..."
virsh define "$DOMAIN_DEFINITION_PATH"
info

# start domain
info "Starting domain '$DOMAIN_NAME'..."
virsh start "$DOMAIN_NAME"
info

# done!
info "Yay \\o/"
