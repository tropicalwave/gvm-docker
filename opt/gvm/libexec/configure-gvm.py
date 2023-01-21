# flake8: noqa: F821,E501
# pylint: disable=undefined-variable
# type: ignore

import csv
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

import pytz
from dateutil.rrule import WEEKLY, rrule
from icalendar import Calendar, Event

if Path("/opt/gvm/.configure-gvm-success").exists():
    sys.exit(0)


def get_scanner_id(scanner_name):
    scanners = gmp.get_scanners()
    scanner_id = None
    for i, scanner in enumerate(scanners.xpath("scanner")):
        if scanner.xpath("name/text()")[0] == scanner_name:
            scanner_id = scanner.xpath("@id")[0]
            break

    return scanner_id


default_scanner_id = get_scanner_id("OpenVAS Default")
if default_scanner_id is None:
    raise Exception("Could not get ID of default scanner")

while True:
    # the scan config list is empty at startup time
    scan_configs = gmp.get_scan_configs()
    if len(scan_configs.xpath("config/@id")) < 6:
        time.sleep(10)
        continue

    config_id = ""
    for i, conf in enumerate(scan_configs.xpath("config")):
        if conf.xpath("name/text()")[0] == "Full and fast":
            config_id = conf.xpath("@id")[0]
            break

    if len(config_id) == 0:
        raise Exception("Could not get ID of default scan config")
    else:
        break


def create_task(name, scanner_id):
    targets = gmp.get_targets()
    target_id = ""
    for i, target in enumerate(targets.xpath("target")):
        if target.xpath("name/text()")[0] == name:
            target_id = target.xpath("@id")[0]
            break

    if len(target_id) == 0:
        raise Exception("Could not get ID of target %s" % name)

    gmp.create_task(
        name=name, config_id=config_id, target_id=target_id, scanner_id=scanner_id
    )


def create_target(name, hosts):
    iana_tcp_udp = "4a4717fe-57d2-11e1-9a26-406186ea4fc5"
    alive_test = [X for X in gmp.types.AliveTest if X.name == "CONSIDER_ALIVE"][0]
    gmp.create_target(
        name=name, hosts=hosts, port_list_id=iana_tcp_udp, alive_test=alive_test
    )


def create_schedule(name, weekday, hour):
    cal = Calendar()
    cal.add("prodid", "-//someid//")
    cal.add("version", "2.0")

    now = datetime.now(tz=pytz.UTC)
    next_wd = rrule(freq=WEEKLY, dtstart=now, byweekday=weekday, count=1)[0]
    event = Event()
    event.add("dtstamp", now)
    event.add(
        "dtstart",
        datetime(next_wd.year, next_wd.month, next_wd.day, hour, tzinfo=pytz.utc),
    )
    event.add("rrule", {"freq": "weekly"})
    cal.add_component(event)

    gmp.create_schedule(name=name, icalendar=cal.to_ical(), timezone="UTC")


created_scanners = []
with open("/opt/gvm/etc/config.csv") as csvfile:
    reader = csv.DictReader(csvfile)
    for row in reader:
        if row["Task"].startswith("#"):
            # Ignore commented line in configuration file
            continue

        taskname = row["Task"]
        scanner = row["Scanner"]
        hosts = row["Hosts"].split(";")
        weekday = int(row["Weekday"])
        hour = int(row["Hour"])

        if re.match("^[a-zA-Z0-9]*$", scanner) is None:
            raise Exception("Invalid scanner name: %s" % scanner)

        if scanner != "" and scanner not in created_scanners:
            # Create scanner
            exit, out = subprocess.getstatusoutput(
                f"/opt/gvm/sbin/gvmd --create-scanner='{scanner}' "
                f"--scanner-type=OpenVAS "
                f"--scanner-host=/opt/gvm/remote-scanners/{scanner}.sock"
            )
            if exit != 0:
                raise Exception(f"Could not create scanner {scanner}: {out}")
            else:
                created_scanners.append(scanner)

        if scanner == "":
            scanner_id = default_scanner_id
        else:
            scanner_id = get_scanner_id(scanner)

        create_schedule(taskname, weekday, hour)
        create_target(taskname, hosts)
        create_task(taskname, scanner_id)

Path("/opt/gvm/.configure-gvm-success").touch()
