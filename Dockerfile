FROM debian:10
RUN apt-key adv --fetch-keys https://dl.yarnpkg.com/debian/pubkey.gpg && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" > \
    /etc/apt/sources.list.d/yarn.list && \
    apt-get -y update && \
    apt-get -y autoremove && \
    apt-get install -y --no-install-recommends \
    bison \
    cmake \
    curl \
    dnsutils \
    doxygen \
    fakeroot \
    gcc-mingw-w64 \
    gettext \
    git \
    gnupg \
    gnutls-bin \
    graphviz \
    heimdal-dev \
    libglib2.0-dev \
    libgnutls28-dev \
    libgpgme-dev \
    libhiredis-dev \
    libical-dev \
    libksba-dev \
    libldap2-dev \
    libmicrohttpd-dev \
    libnet-dev \
    libpcap-dev \
    libpopt-dev \
    libradcli-dev \
    libsnmp-dev \
    libssh-gcrypt-dev \
    libunistring-dev \
    libxml2-dev \
    nmap \
    nsis \
    pkg-config \
    postgresql \
    postgresql-contrib \
    postgresql-server-dev-all \
    python-polib \
    python3-defusedxml \
    python3-lxml \
    python3-paramiko \
    python3-pip \
    python3-psutil \
    redis-server \
    rpm \
    rsync \
    smbclient \
    snmp \
    socat \
    software-properties-common \
    sshpass \
    sudo \
    texlive-fonts-recommended \
    texlive-latex-extra \
    uuid-dev \
    vim \
    virtualenv \
    wget \
    xml-twig-tools \
    xmlstarlet \
    xmltoman \
    xsltproc \
    yarn && \
    rm -rf /var/lib/apt/lists/*

COPY etc/profile.d/* /etc/profile.d/
COPY etc/ld.so.conf.d/gvm.conf /etc/ld.so.conf.d/
COPY etc/sudoers.d/gvm /etc/sudoers.d/

RUN adduser gvm --disabled-password --home /opt/gvm/ --gecos '' && \
    usermod -aG redis gvm

COPY opt/gvm/src/build.sh /opt/gvm/src/
RUN chown gvm:gvm /opt/gvm/src/ && \
    su - gvm -c '/opt/gvm/src/build.sh' && \
    ldconfig

RUN cp /opt/gvm/src/redis-openvas.conf /etc/redis/ && \
    echo "db_address = /run/redis-openvas/redis.sock" > \
    /opt/gvm/etc/openvas/openvas.conf

COPY feeds.tar.gz /opt/gvm/initial_data/
COPY opt/gvm/libexec/* /opt/gvm/libexec/
COPY opt/gvm/sbin/* /opt/gvm/sbin/

COPY etc/systemd/system/* /etc/systemd/system/

RUN systemctl disable redis-server && \
    systemctl enable redis-server@openvas && \
    systemctl enable postgresql && \
    systemctl enable prepare-gvm && \
    systemctl enable gvmd-feedsync.timer && \
    systemctl enable gvmd && \
    systemctl enable gsad && \
    systemctl enable ospd-openvas

EXPOSE 443/tcp
CMD [ "/sbin/init" ]
