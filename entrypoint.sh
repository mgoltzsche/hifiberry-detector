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
# TODO: make readinessprobe succeed only after this script completed successfully.
