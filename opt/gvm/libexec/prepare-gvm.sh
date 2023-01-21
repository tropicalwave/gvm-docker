#!/bin/bash
set -e

readonly LOG_FILE="/var/log/gvm/feedsync.out.log"

if [ -e /opt/gvm/.prepare-gvm-success ]; then
    echo "System already initialized"
    exit 0
fi

for dir in /var/lib/gvm /run/{gvm,gvmd,notus-scanner} /var/lib/openvas; do
    chown -R gvm:gvm "$dir"
done

mkdir -p /opt/gvm/var/log
ln -s /var/log/gvm /opt/gvm/var/log

tar xf /opt/gvm/initial_data/feeds.tar.gz -C /

# Reload NVTs
if ! grep -q NO /opt/gvm/initial_data/initial_feed_sync; then
    su - gvm -c "greenbone-nvt-sync >$LOG_FILE"
fi
sudo openvas -u

su - gvm -c "mkdir -p /opt/gvm/.ssh/"

if [ ! -e /opt/gvm/.is_worker ]; then
    su - gvm -c 'ssh-keygen -N "" -f "/opt/gvm/.ssh/id_rsa"'

    # Set-up PostgreSQL
    sudo -u postgres bash -c 'export LC_ALL="C" && createuser -DRS gvm && createdb -O gvm gvmd'
    sudo -u postgres psql gvmd <<EOF
create role dba with superuser noinherit;
grant dba to gvm;
EOF

    su - gvm -c "gvm-manage-certs -a"

    INITIAL_PW="$(cat /run/secrets/gvm_pass)"
    su - gvm -c "gvmd --create-user=gvm --password='$INITIAL_PW'"
    ADMIN_UUID="$(su - gvm -c 'gvmd --get-users --verbose' | awk '/^gvm / { print $2 }')"
    su - gvm -c "gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value $ADMIN_UUID"
    SCANNER_UUID="$(su - gvm -c 'gvmd --get-scanners' | awk '/OpenVAS Default/ { print $1 }')"
    su - gvm -c "gvmd --modify-scanner=$SCANNER_UUID --scanner-host=/run/gvm/ospd.sock"

    su - gvm -c "mkdir -p ~/.config && cat >~/.config/gvm-tools.conf <<EOF
[gmp]
username=gvm
password=$INITIAL_PW

[unixsocket]
socketpath=/run/gvmd/gvmd.sock
EOF
"
fi

if ! grep -q NO /opt/gvm/initial_data/initial_feed_sync; then
    su - gvm -c "greenbone-feed-sync --type GVMD_DATA >> $LOG_FILE"
    su - gvm -c "greenbone-feed-sync --type SCAP >> $LOG_FILE"
    su - gvm -c "greenbone-feed-sync --type CERT >> $LOG_FILE"
fi

# Necessary for remote scanners as ospd-openvas searches
# for certificates and keys under /usr/var
ln -s /var /usr/

for i in openvas.log gsad.log; do
    touch "/var/log/gvm/$i"
    chown gvm:gvm "/var/log/gvm/$i"
done

# Enable feed validation
curl -f -L https://www.greenbone.net/GBCommunitySigningKey.asc -o /tmp/GBCommunitySigningKey.asc
FPR="$(gpg --with-colons --import-options show-only --import /tmp/GBCommunitySigningKey.asc | awk -F: '/^fpr:/ { print $10 }')"
echo "$FPR:6:" > /tmp/ownertrust.txt
su - gvm -c "gpg --import /tmp/GBCommunitySigningKey.asc"
su - gvm -c "gpg --import-ownertrust < /tmp/ownertrust.txt"
rm -f /tmp/ownertrust.txt /tmp/GBCommunitySigningKey.asc

touch /opt/gvm/.prepare-gvm-success
