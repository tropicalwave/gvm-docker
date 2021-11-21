#!/bin/bash
set -e

readonly LOG_FILE="/var/log/gvm/feedsync.out.log"
exec 1>"$LOG_FILE"

su - gvm -c 'greenbone-nvt-sync'
sudo openvas -u

su - gvm -c 'greenbone-feed-sync --type GVMD_DATA'
su - gvm -c 'greenbone-feed-sync --type SCAP'
su - gvm -c 'greenbone-feed-sync --type CERT'
