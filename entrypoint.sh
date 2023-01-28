#!/bin/sh

set -eu

backupBootConfig() {
	if [ ! -f /boot/config.txt.base ]; then
		echo 'Creating /boot/config.txt backup at /boot/config.txt.base'
		cp -f /boot/config.txt /boot/config.txt.base.tmp
		mv /boot/config.txt.base.tmp /boot/config.txt.base
	else
		echo 'Restoring /boot/config.txt backup from /boot/config.txt.base'
		cp -f /boot/config.txt.base /boot/config.txt.tmp
		mv /boot/config.txt.tmp /boot/config.txt
	fi
}

rebootIfBootConfigChanged() {
	if [ "$REBOOT_ON_CHANGE" = true ]; then
		STATUS=0
		diff /boot/config.txt /tmp/boot-config.txt.prev || STATUS=$?
		if [ $STATUS -eq 1 ]; then
			echo 'Rebooting the system since /boot/config.txt changed'
			sleep 3
			kill -2 1
		fi
	fi
}

writeHostAlsaConfigIfNotExist() {
	if [ -d /host/etc ]; then
		if [ ! -f /host/etc/asound.conf ]; then
			echo 'Installing /etc/asound.conf on the host'
			cp -f /etc/asound.conf /host/etc/asound.conf.tmp &&
			mv /host/etc/asound.conf.tmp /host/etc/asound.conf &&
			sync
		fi
	fi
}

# ARGS: EXITCODE MESSAGE
terminate() {
	echo "$2"
	if [ "$KEEP_RUNNING" = true ]; then
		exec sleep infinity
	else
		exit $1
	fi
}


echo "Detected model no: `i2cget -y 1 0x4d 40`" || true

cp -f /boot/config.txt /tmp/boot-config.txt.prev &&
backupBootConfig && # Make detect-hifiberry idempotent, allow restoring config.
detect-hifiberry && # Writes /boot/config.txt eventually, configuring dtoverlay.
writeHostAlsaConfigIfNotExist &&
echo ready > /tmp/ready &&
rebootIfBootConfigChanged &&
terminate 0 'Configuration is ready' || terminate 1 'ERROR: Hifiberry auto-configuration failed' >&2
