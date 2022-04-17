# gvm-docker

[![GitHub Super-Linter](https://github.com/tropicalwave/gvm-docker/workflows/Lint%20Code%20Base/badge.svg)](https://github.com/marketplace/actions/super-linter)

## Introduction

This deployment sets up a GVM (Greenbone Vulnerability Management)
installation in a container.

After it is set up, the system will

* be accessible by browsing to <https://localhost:4443>,
* be configured with a weekly running task targeting the container itself,
* update GVM feeds daily between noon and 2 PM UTC, and
* update the underlying Debian installation daily.

## Rootfull vs. rootless podman

While not strictly necessary, it's highly recommended to NOT use rootless
podman for running in production.

Background: rootless podman uses slirp4netns to forward network
traffic from/to a container. This is a single process and with GVM scanning a whole
network, this service is heavily overloaded and scans are slowed down.

## Quickstart

The following command will start a single master node:
```bash
./prepare.sh
podman-compose -f docker-compose.yml -f docker-compose-gvm.yml up -d --build
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
podman exec -ti gvm-docker_openvas_1 /bin/bash
# tar -czf /root/feeds.tar.gz var/lib/gvm/cert-data/ var/lib/gvm/scap-data/ var/lib/openvas/plugins/ var/lib/gvm/data-objects/gvmd/
# exit
podman cp gvm-docker_openvas_1:/root/feeds.tar.gz .
```

## Skip initial feed synchronization

To skip the - potentially very long running - initial feed synchronization,
you can execute the below command before starting the container. Please
be aware that this will only work if `feeds.tar.gz` has been initialized
properly beforehand.

```bash
echo NO >.initial_feed_sync
```

## Issues

### cgroups v2

In case of (A) running many scans in parallel and (B) using podman in
combination with cgroups v2 (which limits the number of container processes
to 2048 by default), you might need to increase this limit since `fork()`
syscalls by the scanner could return with the message
`Resource temporarily unavailable`. Therefore, you need to increase this
limit in `/etc/containers/containers.conf` (for a system-wide setting) or
in `$HOME/.config/containers/containers.conf` (for a user-specific setting)
like this:

```bash
[containers]
pids_limit = 10240
```

### Interrupted scans due to failing host alive detection

If scans interrupt at 0% and you're using rootless podman, this might
be due to the target using ICMP ping as "Alive Test" for the hosts (which
is not allowed as a default). In this case, please use a setting like
"Consider Alive".
