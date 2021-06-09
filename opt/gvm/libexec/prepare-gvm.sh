#!/bin/bash
set -e

readonly LOG_FILE="/opt/gvm/var/log/gvm/feedsync.out.log"

if [ -e /opt/gvm/.prepare-gvm-success ]; then
    echo "System already initialized"
    exit 0
fi

tar xf /opt/gvm/initial_data/feeds.tar.gz -C /opt/gvm

INITIAL_PW="$(cat /run/secrets/gvm_pass)"

# Reload NVTs
su - gvm -c "greenbone-nvt-sync >$LOG_FILE"
sudo openvas -u

# Set-up PostgreSQL
sudo -u postgres bash -c 'export LC_ALL="C" && createuser -DRS gvm && createdb -O gvm gvmd'
sudo -u postgres psql gvmd <<EOF
create role dba with superuser noinherit;
grant dba to gvm;
create extension "uuid-ossp";
create extension "pgcrypto";
EOF

su - gvm -c "gvm-manage-certs -a"

su - gvm -c "gvmd --create-user=gvm --password='$INITIAL_PW'"
ADMIN_UUID="$(su - gvm -c 'gvmd --get-users --verbose' | awk '/^gvm / { print $2 }')"
su - gvm -c "gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value $ADMIN_UUID"
SCANNER_UUID="$(su - gvm -c 'gvmd --get-scanners' | awk '/OpenVAS Default/ { print $1 }')"
su - gvm -c "gvmd --modify-scanner=$SCANNER_UUID --scanner-host=/opt/gvm/var/run/ospd.sock"

su - gvm -c "mkdir -p ~/.config && cat >~/.config/gvm-tools.conf <<EOF
[gmp]
username=gvm
password=$INITIAL_PW

[unixsocket]
socketpath=/opt/gvm/var/run/gvmd.sock
EOF
"

su - gvm -c "greenbone-feed-sync --type GVMD_DATA >> $LOG_FILE"
su - gvm -c "greenbone-feed-sync --type SCAP >> $LOG_FILE"
su - gvm -c "greenbone-feed-sync --type CERT >> $LOG_FILE"

# Necessary for remote scanners as ospd-openvas searches
# for certificates and keys under /usr/var
ln -s /opt/gvm/var /usr/

chown gvm:gvm /opt/gvm/var/log/gvm/

for i in openvas.log gsad.log; do
    touch "/opt/gvm/var/log/gvm/$i"
    chown gvm:gvm "/opt/gvm/var/log/gvm/$i"
done

touch /opt/gvm/.prepare-gvm-success
