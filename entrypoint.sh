#!/bin/sh

(set -x; i2cget -y 1 0x4d 40)

set -eu

backupBootConfig() {
	if [ ! -f /boot/config.txt.bak ]; then
		echo 'Creating /boot/config.txt backup at /boot/config.txt.bak'
		cp -f /boot/config.txt /boot/config.txt.bak2
		mv /boot/config.txt.bak2 /boot/config.txt.bak
		sync
	elif ! aplay -l | grep -q hifiberry | grep -q pcm5102; then
		echo 'Restoring /boot/config.txt backup from /boot/config.txt.bak'
		cp -f /boot/config.txt.bak /boot/config.txt2
		mv /boot/config.txt2 /boot/config.txt
		sync
	fi
}

rebootIfBootConfigChanged() {
	if [ "$REBOOT_ON_CHANGE" = true ]; then
		if diff /boot/config.txt /tmp/boot-config.txt.prev; then
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


cp -f /boot/config.txt /tmp/boot-config.txt.prev &&
backupBootConfig && # Make detect-hifiberry idempotent, allow restoring config.
detect-hifiberry && # Writes /boot/config.txt eventually, configuring dtoverlay.
writeHostAlsaConfigIfNotExist &&
echo ready > /tmp/ready &&
rebootIfBootConfigChanged &&
terminate 0 'Configuration is ready' || terminate 1 'ERROR: Hifiberry auto-configuration failed' >&2
