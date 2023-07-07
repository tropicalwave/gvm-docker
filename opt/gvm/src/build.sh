#!/bin/bash
set -e

export PKG_CONFIG_PATH=/opt/gvm/lib/pkgconfig:$PKG_CONFIG_PATH
mkdir -p /opt/gvm/src
cd /opt/gvm/src

INSTALL_PREFIX=/opt/gvm
while IFS=',' read -r product version; do
    git clone -b "$version" --depth 1 \
	"https://github.com/greenbone/$product.git"

    if echo "$product" | grep -E -q "^(ospd-openvas|notus-scanner)"; then
        continue
    elif echo "$product" | grep -q '^gsa$'; then
        cd "$product"
        yarn
        yarn build
        mkdir -p "$INSTALL_PREFIX/share/gvm/gsad/web/"
        cp -r build/* "$INSTALL_PREFIX/share/gvm/gsad/web/"
    else
        if [[ "$product" == "openvas-scanner" ]]; then
            cp openvas-scanner/config/redis-openvas.conf /opt/gvm/src
        fi

        mkdir "$product/build"
        cd "$product/build"
        cmake -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" ..
        make -j "$(nproc)"
        if [[ "$product" != "openvas-smb" ]] && \
                [[ "$product" != "pg-gvm" ]]; then
            make doc
        fi
        make install
    fi

    cd /opt/gvm/src
    rm -rf "$product"
done </opt/gvm/src/versions.csv

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
cd ospd-openvas
pip3 install .
deactivate
cd /opt/gvm/src
rm -rf ospd-scanner

# greenbone-feed-sync installation
git clone -b v23.6.0 --depth 1 \
    https://github.com/greenbone/greenbone-feed-sync.git
virtualenv --python python3.9 /opt/gvm/bin/greenbone-feed-sync-env/
# shellcheck disable=SC1091
source /opt/gvm/bin/greenbone-feed-sync-env/bin/activate
cd greenbone-feed-sync
pip3 install .
python3 -m pip install poetry
poetry install
deactivate
ln -s "/opt/gvm/bin/greenbone-feed-sync-env/bin/greenbone-feed-sync" /opt/gvm/bin/
cd /opt/gvm/src

# notus-scanner installation
virtualenv --python python3.9 /opt/gvm/bin/notus-scanner/
# shellcheck disable=SC1091
source /opt/gvm/bin/notus-scanner/bin/activate
cd notus-scanner
pip3 install .
python3 -m pip install poetry
poetry install

# Run poetry installation again, because the wheel build
# command requires urllib3; however, "poetry install" will
# have removed it...
# We need the wheel build since otherwise the needed file
# daemon.py will not be installed...
python3 -m pip install poetry
poetry build -f wheel
pip install "$(ls dist/notus_scanner-*.whl)" --force-reinstall
deactivate
cd /opt/gvm/src
rm -rf notus-scanner

mkdir -p /run/gvm{,d}/ /run/{gsad,notus-scanner}/
mkdir -p /var/log/gvm
chown gvm:gvm /var/log/gvm

mkdir -p /var/lib/redis/openvas
chown redis:redis /var/lib/redis/openvas
