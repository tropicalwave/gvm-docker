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
You can check that it finished by checking that one task was created.

## Connect additional scanner/s

To connect an additional scanner to the master node, checkout the
repository on another host and run the following commands:
```bash
podman-compose -f docker-compose.yml -f docker-compose-ospd.yml up -d --build

# Wait until the following command shows that all services are running.
podman-compose exec openvas systemctl status
```

Thereafter, run the following commands on the host of the master node
and follow the instructions:
```bash
podman-compose exec openvas /bin/bash
> /opt/gvm/sbin/add-scanner.sh <some name> <IP address of additional scanner>
```

The scanner will now be shown at <https://localhost:4443/scanners> and
can be used within tasks.

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
