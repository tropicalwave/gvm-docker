# flake8: noqa: F821,E501
# pylint: disable=undefined-variable
# type: ignore

import csv
from datetime import datetime


def get_tasks_and_ids():
    ret = {}
    tasks = gmp.get_tasks(filter_string="rows=-1")
    for i, task in enumerate(tasks.xpath("task")):
        ret[task.find("name").text] = task.xpath("@id")[0]

    return ret


today = datetime.today().replace(hour=0, minute=0, second=0, microsecond=0)
tasks = get_tasks_and_ids()
overrides = gmp.get_overrides()
for override in overrides.xpath("override"):
    oid = override.xpath("@id")[0]
    gmp.delete_override(oid, ultimate=True)

with open("/opt/gvm/etc/overrides.csv") as csvfile:
    reader = csv.DictReader(csvfile, delimiter=";")
    for row in reader:
        if row["NVT"].startswith("#"):
            # Ignore commented line in configuration file
            continue

        nvt = row["NVT"]
        task = row["Task"]
        ip = row["IP"]
        port = row["Port"] or None
        expiration = row["Expiration"]
        reason = row["Reason"]

        if expiration == "":
            expire_days = -1
        else:
            expire_days = (datetime.strptime(expiration, "%Y-%m-%d") - today).days
            if expire_days < 1:
                print(f"Ignore override due to expiration in the past: {reason}")
                continue

        if ip == "":
            hosts = None
        else:
            hosts = ip.split(",")

        if task == "":
            task_id = None
        else:
            task_id = tasks[task]

        gmp.create_override(
            reason,
            nvt,
            days_active=expire_days,
            hosts=hosts,
            port=port,
            task_id=task_id,
            new_severity=-1,
        )
