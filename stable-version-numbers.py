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
        f"https://registry.hub.docker.com/v2/repositories/greenbone/{product}/tags?page_size=1000",
        timeout=60,
    )
    r.raise_for_status()
    obj = json.loads(r.text)
    digests = {
        X["name"]: [Y["digest"] for Y in X["images"] if Y["architecture"] == "amd64"][0]
        for X in obj["results"]
        if X["name"] == "stable"
        or len(X["name"].split(".")) == 3
        and len([Y for Y in X["images"] if Y["architecture"] == "amd64"]) > 0
    }
    assert "stable" in digests.keys(), f"{product} {digests}"
    stable_version = [
        X
        for X, Y in digests.items()
        if Y == digests["stable"]
        and X != "stable"
        or (
            product == "gvmd"
            and digests["stable"]
            == "sha256:8a031e85b899fff4bdb4c5312bb029f524e85f039459227d7a44da3fb3e48821"
            and X == "23.10.0"
        )
    ]
    assert len(stable_version) == 1, f"{product}, {stable_version}, {digests}"
    print(f"{product},v{stable_version[0]}")
