#!/bin/bash
if [ ! -e /opt/gvm/.is_worker ]; then
    echo "This command should only be executed on a remote scanner."
    exit 1
fi

TYPE="$1"
PUBKEY="$2"
COMMENT="$3"

if [ -z "$TYPE" ] || [ -z "$PUBKEY" ] || [ -z "$COMMENT" ]; then
    echo "Please enter valid arguments."
    exit 1
fi

su -c "echo \"$TYPE $PUBKEY $COMMENT\" >>/opt/gvm/.ssh/authorized_keys" gvm
