#!/bin/bash
#set -x

# ks-prep.sh
#
# support script for preparing templates on opennebula base cloud
#
# license: Apache License 2.0
# author:  jahor <jahor@jhr.cz>

# how it works simplified
# =======================
# requires vm templates with shared persistent volume
#
# - starts installation with kickstart with shutdown in the end
#   - vm template expects acpi disabled
#   - first drive is cdrom with install iso
#   - kernel and vmlinuz are extracted for using kickstart params
# - waits for the vm to fall into UNKNOWN state
# - deletes the previously created vm
# - starts second instance from with the previously used volume as OS image
# - waits for the vm to fall into UNKNOWN state
#   - THERE is time for checking that all is ok and some modifications
#   - after hacks are done, shutdown the machine
# - when the machine is down / in UNKNOWN state / the volume could be cloned

# NOTES
# ======
#
# sample onevm show $id output:
# ---8<---
# LCM_STATE           : UNKNOWN             
# --->8---
# or
# ---8<---
# LCM_STATE           : UNKNOWN             
# --->8---

TPLID_KS=93
TPLID_POSTINST=94

echo "kickstart instance starting..."
id=$(onetemplate instantiate $TPLID_KS | grep 'VM ID:' | cut -d : -f 2)
#onevm show $id | grep LCM_STATE | grep RUNNING || exit 1
echo "started ok, id=$id"
#id=

echo "waiting for kickstart finish (vm shutdown results by UNKNOWN vm state)"
while true
do
	onevm show $id | grep LCM_STATE | grep -q UNKNOWN && break
	echo -n .
	sleep 5
done
echo
echo "vm shutdown detected, deleting..."
onevm delete $id
echo "delete ok"

echo "postinstall instance starting..."
id=$(onetemplate instantiate $TPLID_POSTINST | grep 'VM ID:' | cut -d : -f 2)
#onevm show $id | grep LCM_STATE | grep RUNNING || exit 1
echo "started ok, id=$id"

echo "prepard postinstall state vmid: $id"

echo "waiting for check and snapprep (vm shutdown results by UNKNOWN vm state)"
while true
do
	onevm show $id | grep LCM_STATE | grep -q UNKNOWN && break
	echo -n .
	sleep 5
done
echo
echo "vm shutdown detected, ready for cloning..."

