# checkov:skip=CKV_DOCKER_2:healthcheck not enabled
# checkov:skip=CKV_DOCKER_3:no user necessary
# checkov:skip=CKV2_DOCKER_1:sudo required for application
FROM debian:12 AS base
RUN apt-get -y update -o APT::Update::Error-Mode=any && \
    apt-get install -y --no-install-recommends curl gnupg ca-certificates && \
    curl -sL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > \
    /etc/apt/sources.list.d/nodesource.list && \
    echo "Package: nodejs" > /etc/apt/preferences.d/nodejs && \
    echo "Pin: origin deb.nodesource.com" >> /etc/apt/preferences.d/nodejs && \
    echo "Pin-Priority: 600" >> /etc/apt/preferences.d/nodejs && \
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
    heimdal-multidev \
    krb5-multidev \
    less \
    libbsd-dev \
    libcjson-dev \
    libcurl4-openssl-dev \
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
    nodejs \
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
    xsltproc && \
    rm -rf /var/lib/apt/lists/*

COPY etc/profile.d/* /etc/profile.d/
COPY etc/ld.so.conf.d/gvm.conf /etc/ld.so.conf.d/
COPY etc/sudoers.d/gvm /etc/sudoers.d/

RUN adduser gvm --disabled-password --home /opt/gvm/ --gecos '' && \
    chmod 755 /opt/gvm && \
    usermod -aG redis gvm

COPY opt/gvm/src/* /opt/gvm/src/
RUN /opt/gvm/src/build.sh && \
    ldconfig

RUN cp /opt/gvm/src/redis-openvas.conf /etc/redis/ && \
    echo "db_address = /run/redis-openvas/redis.sock" > \
    /etc/openvas/openvas.conf && \
    printf "jit = off\nssl_min_protocol_version = 'TLSv1.3'\n" \
    >> /etc/postgresql/15/main/postgresql.conf

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
    systemctl enable set-overrides && \
    systemctl enable prepare-gvm && \
    systemctl enable gvmd-feedsync.timer && \
    systemctl enable gvmd && \
    systemctl enable gsad && \
    systemctl enable notus-scanner && \
    systemctl enable ospd-openvas

FROM base AS openvas
# checkov:skip=CKV_DOCKER_1:SSH intentionally exposed
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
