#!/bin/sh

(set -x; i2cget -y 1 0x4d 40)

set -eu

detect-hifiberry && (
if [ -d /host/etc ]; then
	if [ ! -f /host/etc/asound.conf ]; then
		echo Installing /etc/asound.conf on the host
		cp /etc/asound.conf /host/etc/asound.conf.tmp &&
		mv /host/etc/asound.conf.tmp /host/etc/asound.conf
	fi
fi
) &&
echo ready /tmp/ready &&
echo Configuration is ready || echo 'ERROR: Hifiberry auto-configuration failed' >&2

# TODO: restart machine when config was changed.

if [ "$KEEP_RUNNING" = true ]; then
	sleep infinity &
	SPID=$!
	trap "kill $SPID" 1 2 15
	wait $SPID
fi
