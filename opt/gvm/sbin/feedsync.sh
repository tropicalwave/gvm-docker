#!/bin/bash
set -e

readonly LOG_FILE="/var/log/gvm/feedsync.out.log"
exec 1>"$LOG_FILE"

su - gvm -c 'greenbone-feed-sync'
sudo openvas -u

tar -czf /root/feeds.tar.gz \
    var/lib/notus/ \
    var/lib/gvm/cert-data/ \
    var/lib/gvm/scap-data/ \
    var/lib/openvas/plugins/ \
    var/lib/gvm/data-objects/gvmd/
mv /root/feeds.tar.gz /opt/gvm/initial_data/
