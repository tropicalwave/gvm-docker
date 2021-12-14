#!/bin/bash
set -e

if [ ! -e feeds.tar.gz ]; then
    tar czf feeds.tar.gz --files-from /dev/null
fi

if [ ! -e .gvm_pass ]; then
    pwgen 20 -s 1 >.gvm_pass
fi

if [ ! -e .initial_feed_sync ]; then
    touch .initial_feed_sync
fi
