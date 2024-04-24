# flake8: noqa: F821,E501
# pylint:disable=undefined-variable,invalid-name,import-error
# pylint:disable=broad-exception-raised,missing-function-docstring
# type: ignore

"""Configure schedules, targets, and tasks in GVM"""

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
    scanners = gmp.get_scanners(filter_string="rows=-1")
    sid = None
    for _, s in enumerate(scanners.xpath("scanner")):
        if s.xpath("name/text()")[0] == scanner_name:
            sid = s.xpath("@id")[0]
            break

    return sid


def get_schedule_id(schedule_name):
    schedules = gmp.get_schedules(filter_string="rows=-1")
    schedule_id = None
    for _, schedule in enumerate(schedules.xpath("schedule")):
        if schedule.xpath("name/text()")[0] == schedule_name:
            schedule_id = schedule.xpath("@id")[0]
            break

    return schedule_id


def get_target_id(target_name):
    targets = gmp.get_targets(filter_string="rows=-1")
    target_id = None
    for _, target in enumerate(targets.xpath("target")):
        if target.xpath("name/text()")[0] == target_name:
            target_id = target.xpath("@id")[0]
            break

    return target_id


def create_task(name, sid):
    gmp.create_task(
        name=name,
        config_id=config_id,
        target_id=get_target_id(name),
        schedule_id=get_schedule_id(name),
        scanner_id=sid,
    )


def create_target(name, hostlist):
    iana_tcp_udp = "4a4717fe-57d2-11e1-9a26-406186ea4fc5"
    gmp.create_target(name=name, hosts=hostlist, port_list_id=iana_tcp_udp)


def create_schedule(name, wday, hours):
    cal = Calendar()
    cal.add("prodid", "-//someid//")
    cal.add("version", "2.0")

    now = datetime.now(tz=pytz.UTC)
    next_wd = rrule(freq=WEEKLY, dtstart=now, byweekday=wday, count=1)[0]
    event = Event()
    event.add("dtstamp", now)
    event.add(
        "dtstart",
        datetime(next_wd.year, next_wd.month, next_wd.day, hours, tzinfo=pytz.utc),
    )
    event.add("rrule", {"freq": "weekly"})
    cal.add_component(event)

    gmp.create_schedule(name=name, icalendar=cal.to_ical(), timezone="UTC")


default_scanner_id = get_scanner_id("OpenVAS Default")
if default_scanner_id is None:
    raise Exception("Could not get ID of default scanner")

while True:
    # the scan config list is empty at startup time
    scan_configs = gmp.get_scan_configs(filter_string="rows=-1")
    if len(scan_configs.xpath("config/@id")) < 6:
        time.sleep(10)
        continue

    config_id = ""
    for _, conf in enumerate(scan_configs.xpath("config")):
        if conf.xpath("name/text()")[0] == "Full and fast":
            config_id = conf.xpath("@id")[0]
            break

    if len(config_id) == 0:
        raise Exception("Could not get ID of default scan config")

    break

created_scanners = []
with open("/opt/gvm/etc/config.csv", encoding="utf-8") as csvfile:
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
            raise Exception(f"Invalid scanner name: {scanner}")

        if scanner != "" and scanner not in created_scanners:
            # Create scanner
            sts, out = subprocess.getstatusoutput(
                f"/opt/gvm/sbin/gvmd --create-scanner='{scanner}' "
                f"--scanner-type=OpenVAS "
                f"--scanner-host=/opt/gvm/remote-scanners/{scanner}.sock"
            )
            if sts != 0:
                raise Exception(f"Could not create scanner {scanner}: {out}")

            created_scanners.append(scanner)

        if scanner == "":
            scanner_id = default_scanner_id
        else:
            scanner_id = get_scanner_id(scanner)

        create_schedule(taskname, weekday, hour)
        create_target(taskname, hosts)
        create_task(taskname, scanner_id)

Path("/opt/gvm/.configure-gvm-success").touch()
