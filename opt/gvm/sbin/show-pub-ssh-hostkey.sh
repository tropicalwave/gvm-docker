#!/bin/bash
awk '{ print $2 }' /etc/ssh/ssh_host_ecdsa_key.pub
