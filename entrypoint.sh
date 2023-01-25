#!/bin/sh

set -eu

detect-hifiberry

if [ -d /host/etc ]; then
	if [ ! -f /host/etc/asound.conf ]; then
		echo Installing /etc/asound.conf on the host
		cp /etc/asound.conf /host/etc/asound.conf.tmp
		mv /host/etc/asound.conf.tmp /host/etc/asound.conf
	fi
fi

# TODO: restart machine when config was changed.
# TODO: make readinessprobe succeed only at this point.

if [ "$KEEP_RUNNING" = true ]; then
	sleep infinity &
	SPID=$!
	trap "kill $SPID" 1 2 15
	wait $SPID
fi
