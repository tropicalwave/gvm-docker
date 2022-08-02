#!/bin/bash
set -e

export PKG_CONFIG_PATH=/opt/gvm/lib/pkgconfig:$PKG_CONFIG_PATH
mkdir -p /opt/gvm/src
cd /opt/gvm/src

VERSION=v22.4.0
INSTALL_PREFIX=/opt/gvm
for product in \
        gvm-libs \
        pg-gvm \
        openvas \
        gvmd \
        gsa \
        gsad \
        ospd-openvas \
        openvas-smb; do
    TAG="$VERSION"

    git clone -b "$TAG" --depth 1 \
	"https://github.com/greenbone/$product.git"

    if echo $product | grep -q ospd-openvas; then
        continue
    elif echo $product | grep -q '^gsa$'; then
        cd "$product"
        yarn
        yarn build
        mkdir -p "$INSTALL_PREFIX/share/gvm/gsad/web/"
        cp -r build/* "$INSTALL_PREFIX/share/gvm/gsad/web/"
    else
        if [[ "$product" == "openvas" ]]; then
            cp openvas/config/redis-openvas.conf /opt/gvm/src
        fi

        mkdir "$product/build"
        cd "$product/build"
        cmake -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" ..
        make
        if [[ "$product" != "openvas-smb" ]] && \
                [[ "$product" != "pg-gvm" ]]; then
            make doc
        fi
        make install
    fi

    cd /opt/gvm/src
    rm -rf "$product"
done

# gvm-tools
git clone -b v22.6.1 --depth 1 \
    https://github.com/greenbone/gvm-tools.git
virtualenv --python python3.9  /opt/gvm/bin/gvm-tools/
# shellcheck disable=SC1091
source /opt/gvm/bin/gvm-tools/bin/activate
cd gvm-tools
pip3 install .
pip3 install tz icalendar
deactivate
for i in gvm-cli gvm-pyshell gvm-script; do
    ln -s "/opt/gvm/bin/gvm-tools/bin/$i" /opt/gvm/bin/
done

cd /opt/gvm/src
rm -rf gvm-tools

# ospd-scanner installation
virtualenv --python python3.9 /opt/gvm/bin/ospd-scanner/
# shellcheck disable=SC1091
source /opt/gvm/bin/ospd-scanner/bin/activate
mkdir -p /run/gvm{,d}/ /run/gsad/
cd ospd-openvas
pip3 install .
deactivate
cd /opt/gvm/src
rm -rf ospd-scanner

mkdir -p /var/log/gvm
chown gvm:gvm /var/log/gvm
