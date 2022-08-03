#!/bin/bash
set -e

if [ ! -e feeds/feeds.tar.gz ]; then
    mkdir -p feeds
    tar czf feeds/feeds.tar.gz --files-from /dev/null
fi

if [ ! -e .gvm_pass ]; then
    pwgen 20 -s 1 >.gvm_pass
fi

if [ ! -e feeds/initial_feed_sync ]; then
    touch feeds/initial_feed_sync
fi
