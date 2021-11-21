# gvm-docker

[![GitHub Super-Linter](https://github.com/tropicalwave/gvm-docker/workflows/Lint%20Code%20Base/badge.svg)](https://github.com/marketplace/actions/super-linter)

## Introduction

This deployment sets up a GVM (Greenbone Vulnerability Management)
installation in a container.

After it is set up, the system will

* be accessible by browsing to <https://localhost:4443>,
* update GVM feeds daily between noon and 2 PM UTC, and
* update the underlying Debian installation daily.

## Rootfull vs. rootless podman

While not strictly necessary, it's highly recommended to NOT use rootless
podman for running in production.

Background: rootless podman uses slirp4netns to forward network
traffic from/to a container. This is a single process and with GVM scanning a whole
network, this service is heavily overloaded and scans are slowed down.

## Quickstart

```bash
./prepare.sh
podman-compose up -d
```

## Login

Browse to <https://localhost:4443>

* user: gvm
* password: (see content of `.gvm_pass`)

The initialization phase takes some minutes (more than 15 minutes).
You can check that it finished by looking at the scanner configs and the
NVTs (their number must be larger than 0).

## Retrieve initial feed file from already running system

To speed up startups of the system at a later point by decreasing the
time for the initial feed sync, the file `feeds.tar.gz` can be retrieved
from a running system.

```bash
podman exec -ti gvm_openvas_1 /bin/bash
# tar -czf /root/feeds.tar.gz var/lib/gvm/cert-data/ var/lib/gvm/scap-data/ var/lib/openvas/plugins/ var/lib/gvm/data-objects/gvmd/
# exit
podman cp gvm_openvas_1:/root/feeds.tar.gz .
```
