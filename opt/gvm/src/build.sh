#!/bin/bash
set -e

export PKG_CONFIG_PATH=/opt/gvm/lib/pkgconfig:$PKG_CONFIG_PATH
mkdir -p /opt/gvm/src
cd /opt/gvm/src

VERSION=v21.4.3
for product in gvm-libs openvas gvmd gsa ospd-openvas ospd; do
    TAG="$VERSION"
    if [ "$product" == "gvmd" ]; then
        TAG="v21.4.4"
    fi

    git clone -b "$TAG" --depth 1 \
	"https://github.com/greenbone/$product.git"

    if echo $product | grep -q ^ospd; then
        continue
    elif echo $product | grep -q ^openvas; then
        cp openvas/config/redis-openvas.conf /opt/gvm/src
    fi

    mkdir "$product/build"
    cd "$product/build"
    cmake -DCMAKE_INSTALL_PREFIX=/opt/gvm ..
    make
    make doc
    make install
    cd /opt/gvm/src
    rm -rf "$product"
done

# gvm-tools
git clone -b v21.1.0 --depth 1 \
    https://github.com/greenbone/gvm-tools.git
virtualenv --python python3.7  /opt/gvm/bin/gvm-tools/
# shellcheck disable=SC1091
source /opt/gvm/bin/gvm-tools/bin/activate
cd gvm-tools
pip3 install .
deactivate
ln -s /opt/gvm/bin/gvm-tools/bin/gvm-pyshell /opt/gvm/bin/
ln -s /opt/gvm/bin/gvm-tools/bin/gvm-cli /opt/gvm/bin/
cd /opt/gvm/src
rm -rf gvm-tools

# openvas-smb
git clone --depth 1 \
    https://github.com/greenbone/openvas-smb.git
mkdir openvas-smb/build
cd openvas-smb/build
cmake -DCMAKE_INSTALL_PREFIX=/opt/gvm ..
make
make install
cd /opt/gvm/src
rm -rf openvas-smb

# ospd and ospd-scanner
virtualenv --python python3.7  /opt/gvm/bin/ospd-scanner/
# shellcheck disable=SC1091
source /opt/gvm/bin/ospd-scanner/bin/activate
mkdir -p /run/gvm/
cd ospd
pip3 install .
cd /opt/gvm/src
cd ospd-openvas
pip3 install .
deactivate

mkdir -p /var/log/gvm
chown gvm:gvm /var/log/gvm
