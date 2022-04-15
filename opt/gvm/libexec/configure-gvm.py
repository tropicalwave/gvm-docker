# pylint: disable=undefined-variable
# type: ignore

import csv
import sys
import time
from datetime import datetime
from pathlib import Path

import pytz
from dateutil.rrule import WEEKLY, rrule
from icalendar import Calendar, Event

if Path("/opt/gvm/.configure-gvm-success").exists():
    sys.exit(0)

scanners = gmp.get_scanners()  # noqa: F821
scanner_id = ""
for i, scanner in enumerate(scanners.xpath("scanner")):
    if scanner.xpath("name/text()")[0] == "OpenVAS Default":
        scanner_id = scanner.xpath("@id")[0]
        break

if len(scanner_id) == 0:
    raise Exception("Could not get ID of default scanner")

while True:
    # the scan config list is empty at startup time
    scan_configs = gmp.get_scan_configs()
    if len(scan_configs.xpath("config/@id")) == 0:
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


def create_task(name):
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
    gmp.create_target(name=name, hosts=hosts, port_list_id=iana_tcp_udp)


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


with open("/opt/gvm/etc/config.csv") as csvfile:
    reader = csv.DictReader(filter(lambda row: row[0] != "#", csvfile))
    for row in reader:
        taskname = row["taskname"]
        hosts = row["hosts"].split(";")
        weekday = int(row["weekday"])
        hour = int(row["hour"])

        create_schedule(taskname, weekday, hour)
        create_target(taskname, hosts)
        create_task(taskname)

Path("/opt/gvm/.configure-gvm-success").touch()
