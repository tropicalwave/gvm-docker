#!/usr/bin/python3
# pylint:disable=invalid-name,import-error
"""Retrieve and output latest stable product version numbers"""
import json

import requests

for product in [
    "gvm-libs",
    "pg-gvm",
    "openvas-scanner",
    "gvmd",
    "gsa",
    "gsad",
    "notus-scanner",
    "ospd-openvas",
    "openvas-smb",
]:
    r = requests.get(
        f"https://api.github.com/repos/greenbone/{product}/releases/latest",
        timeout=60,
    )
    r.raise_for_status()
    data = r.json()
    print(f"{product},{data.get('tag_name')}")
