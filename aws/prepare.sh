#!/bin/bash
if ! test -e ../feeds/feeds.tar.gz; then
    tar czvf ../feeds/feeds.tar.gz --files-from=/dev/null
fi

cd .. && git archive --prefix gvm-docker/ HEAD -o aws/head.tar.gz
