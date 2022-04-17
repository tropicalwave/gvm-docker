FROM debian:11 AS base
RUN apt-get -y update && \
    apt-get install -y --no-install-recommends gnupg ca-certificates && \
    apt-key adv --fetch-keys https://dl.yarnpkg.com/debian/pubkey.gpg && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" > \
    /etc/apt/sources.list.d/yarn.list && \
    apt-get -y update && \
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
    /etc/openvas/openvas.conf

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
    systemctl enable configure-gvm && \
    systemctl enable prepare-gvm && \
    systemctl enable gvmd-feedsync.timer && \
    systemctl enable gvmd && \
    systemctl enable gsad && \
    systemctl enable ospd-openvas

FROM base AS openvas
EXPOSE 22/tcp
RUN sed -i 's/postgresql.service//g' /etc/systemd/system/prepare-gvm.service && \
    systemctl disable redis-server && \
    systemctl disable postgresql && \
    systemctl enable redis-server@openvas && \
    systemctl enable prepare-gvm && \
    systemctl enable gvmd-feedsync.timer && \
    systemctl enable ospd-openvas && \
    touch /opt/gvm/.is_worker
