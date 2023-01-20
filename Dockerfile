FROM debian:11 AS base
RUN apt-get -y update -o APT::Update::Error-Mode=any && \
    apt-get install -y --no-install-recommends curl gnupg ca-certificates && \
    curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor > /usr/share/keyrings/yarnkey.gpg && \
    curl -sL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor > /usr/share/keyrings/nodekey.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian/ stable main" > \
    /etc/apt/sources.list.d/yarn.list && \
    echo "deb [signed-by=/usr/share/keyrings/nodekey.gpg] https://deb.nodesource.com/node_14.x bullseye main" > \
    /etc/apt/sources.list.d/nodesource.list && \
    apt-get -y update -o APT::Update::Error-Mode=any && \
    apt-get -y autoremove && \
    apt-get install -y --no-install-recommends \
    bison \
    build-essential \
    cmake \
    curl \
    dnsutils \
    doxygen \
    fakeroot \
    gcc-mingw-w64 \
    gettext \
    git \
    gnutls-bin \
    graphviz \
    heimdal-dev \
    less \
    libbsd-dev \
    libglib2.0-dev \
    libgnutls28-dev \
    libgpgme-dev \
    libhiredis-dev \
    libical-dev \
    libjson-glib-dev \
    libksba-dev \
    libldap2-dev \
    libmicrohttpd-dev \
    libnet-dev \
    libpaho-mqtt-dev \
    libpcap-dev \
    libpopt-dev \
    libradcli-dev \
    libsnmp-dev \
    libssh-gcrypt-dev \
    libunistring-dev \
    libxml2-dev \
    mosquitto \
    openssh-server \
    nmap \
    node.js \
    nsis \
    pkg-config \
    postgresql \
    postgresql-contrib \
    postgresql-server-dev-all \
    python3-polib \
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
    systemd \
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
RUN /opt/gvm/src/build.sh && \
    ldconfig

RUN cp /opt/gvm/src/redis-openvas.conf /etc/redis/ && \
    echo "db_address = /run/redis-openvas/redis.sock" > \
    /etc/openvas/openvas.conf && \
    echo 'jit = off' >> /etc/postgresql/13/main/postgresql.conf

COPY opt/gvm/libexec/* /opt/gvm/libexec/
COPY opt/gvm/sbin/* /opt/gvm/sbin/
COPY opt/gvm/etc/* /opt/gvm/etc/

COPY etc/systemd/system/* /etc/systemd/system/

CMD [ "/lib/systemd/systemd" ]

FROM base AS gvm
EXPOSE 443/tcp
RUN systemctl disable redis-server && \
    systemctl disable ssh && \
    systemctl enable redis-server@openvas && \
    systemctl enable postgresql && \
    systemctl enable mosquitto && \
    systemctl enable configure-gvm && \
    systemctl enable prepare-gvm && \
    systemctl enable gvmd-feedsync.timer && \
    systemctl enable gvmd && \
    systemctl enable gsad && \
    systemctl enable notus-scanner && \
    systemctl enable ospd-openvas

FROM base AS openvas
EXPOSE 22/tcp
RUN sed -i 's/postgresql.service//g' /etc/systemd/system/prepare-gvm.service && \
    systemctl disable redis-server && \
    systemctl disable postgresql && \
    systemctl enable mosquitto && \
    systemctl enable redis-server@openvas && \
    systemctl enable prepare-gvm && \
    systemctl enable gvmd-feedsync.timer && \
    systemctl enable notus-scanner && \
    systemctl enable ospd-openvas && \
    touch /opt/gvm/.is_worker
