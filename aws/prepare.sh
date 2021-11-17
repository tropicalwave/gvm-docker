#!/bin/bash
if ! test -e ../feeds.tar.gz ; then
    tar czvf ../feeds.tar.gz --files-from=/dev/null
fi

cd .. && git archive --prefix gvm-docker/ HEAD -o aws/head.tar.gz
