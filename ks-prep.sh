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

# there is a way to skip some steps by using special variables
#   * VMID_KS
#   * VMID_POSINST
# real example:
#   VMID_KS=skip VMID_POSINST=631 bash ks-prep.sh

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

# one1-CentOS-6.3-x86_64-netinstall-persistent [KSINSTALLER] [DHCP]
TPLID_KS=93
# one1-CentOS-6.3-x86_64-postinstall-persistent [TEST-POOL]
TPLID_POSTINST=94

echo "kickstart instance starting..."

if [ -z "$VMID_KS" ]
then
	cmd_out=$(onetemplate instantiate $TPLID_KS 2>&1)
	id=$(echo "$cmd_out" | grep 'VM ID:' | cut -d : -f 2)
	if [ -n "$id" ]
	then
		#onevm show $id | grep LCM_STATE | grep RUNNING || exit 1
		echo "started ok, id=$id"
	else
		echo "something get wrong, no, no vmid"
		echo "$cmd_out" | sed -e 's,^,  :,g'
	fi
else
	id="$VMID_KS"
	echo "using already requested vmid $id"
fi

echo "waiting for kickstart finish (vm shutdown results by UNKNOWN vm state)"

if [ "$id" = "skip" ]
then
	echo "skipping vm management as requested"
else
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
fi

# wait for persistent resources to be freed from previous vm
sleep 10

echo "postinstall instance starting..."

if [ -z "$VMID_KS" ]
then
	cmd_out=$(onetemplate instantiate $TPLID_POSTINST 2>&1)
	id=$(echo "$cmd_out" | grep 'VM ID:' | cut -d : -f 2)
	if [ -n "$id" ]
	then
		#onevm show $id | grep LCM_STATE | grep RUNNING || exit 1
		echo "started ok, id=$id"
	else
		echo "something get wrong, no, no vmid"
		echo "$cmd_out" | sed -e 's,^,  :,g'
	fi
else
	id="$VMID_POSINST"
	echo "using already requested vmid $id"
fi

echo "prepard postinstall state vmid: $id"

echo "waiting for check and snapprep (vm shutdown results by UNKNOWN vm state)"

if [ "$id" = "skip" ]
then
	echo "skipping vm management as requested"
else
	while true
	do
		onevm show $id | grep LCM_STATE | grep -q UNKNOWN && break
		echo -n .
		sleep 5
	done
fi
echo
echo "vm shutdown detected, ready for cloning..."

