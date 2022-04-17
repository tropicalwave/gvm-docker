#!/bin/bash
SCANNER_NAME="$1"
HOST="$2"
PORT="$3"

if [ -z "$PORT" ]; then
    PORT=22
fi

if [ -z "$HOST" ] || [ -z "$SCANNER_NAME" ]; then
    echo "Usage: $0 <scanner name> <hostname or ip address of remote scanner> [SSH port]"
    exit 1
elif [ "$(id -u)" -gt 0 ]; then
    echo "This script must be run as user gvm."
    exit 1
fi

if [[ "$SCANNER_NAME" =~ [^a-zA-Z0-9] ]]; then
    echo "Invalid scanner name. Must only contain characters and digits."
    exit 1
fi

read -r -p "Please enter the output of the command /opt/gvm/sbin/show-pub-ssh-hostkey.sh on the remote scanner: " EXPECTED_SSH_PUBKEY
REMOTE_INFO="$(ssh-keyscan -p "$PORT" -t ecdsa "$HOST")"
REAL_SSH_PUBKEY="$(echo "$REMOTE_INFO" | awk '{ print $3 }')"

if [ "$EXPECTED_SSH_PUBKEY" != "$REAL_SSH_PUBKEY" ]; then
    echo "Public SSH hostkey of $HOST does not match to expected one: $REAL_SSH_PUBKEY"
    exit 1
fi

# shellcheck disable=SC2016
su -c 'mkdir -p "$HOME/remote-scanners"' gvm
su -c "echo '$REMOTE_INFO' >> \"\$HOME/.ssh/known_hosts\"" gvm
su -c "echo -e 'HOST=$HOST\\nREMOTE_PORT=$PORT' >\$HOME/remote-scanners/$SCANNER_NAME.env" gvm
su -c "/opt/gvm/sbin/gvmd --create-scanner='$SCANNER_NAME' --scanner-type=OpenVAS --scanner-host=\"\$HOME/remote-scanners/$SCANNER_NAME.sock\"" gvm

echo "Please issue the following command on the remote-scanner:"
echo "/opt/gvm/sbin/allow-manager.sh $(cat /opt/gvm/.ssh/id_rsa.pub)"
echo
read -r -p "Press any key afterwards to continue..."

systemctl enable "ssh-tunnel-scanner@$SCANNER_NAME.service"
systemctl start "ssh-tunnel-scanner@$SCANNER_NAME.service"
