#!/bin/sh

set -eu

alsaDeviceDetected() {
	aplay -l | grep hifiberry | grep -q pcm5102
}

backupBootConfig() {
	if [ ! -f /host/boot/config.txt.base ]; then
		echo 'Creating /boot/config.txt backup at /boot/config.txt.base'
		cp -f /host/boot/config.txt /host/boot/config.txt.base.tmp
		mv /host/boot/config.txt.base.tmp /host/boot/config.txt.base
	fi
	cp -f /host/boot/config.txt.base /boot/config.txt.tmp
	mv /boot/config.txt.tmp /boot/config.txt
	sync
}

writeBootConfig() {
	# Updating /boot/config.txt
	cp -f /boot/config.txt /host/boot/config.txt.tmp
	mv /host/boot/config.txt.tmp /host/boot/config.txt
	sync
}

rebootIfBootConfigChanged() {
	if [ "$REBOOT_ON_CHANGE" = true ]; then
		STATUS=0
		diff /boot/config.txt /host/boot/config.txt || STATUS=$?
		if [ $STATUS -eq 1 ]; then
			writeBootConfig
			echo 'Rebooting the system since /boot/config.txt changed'
			sleep 3
			kill -2 1
		fi
	else
		writeBootConfig
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

waitForI2CDevicesToBecomeAvailable() {
	for _ in $(seq 1 15); do
		sleep 1
		find /dev -path '/dev/i2c*' | grep -q . && return 0 || true
		echo 'Waiting for I2C device files to become available' >&2
	done
	echo 'Timed out waiting 15s for device files to become available' >&2
	return 1
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


if alsaDeviceDetected; then
	echo ready > /tmp/ready &&
	terminate 0 'Skipping auto-configuration since ALSA device found'
else
	echo 'Detecting Hifiberry I2C device ...'
	modprobe i2c-dev &&
	waitForI2CDevicesToBecomeAvailable &&
	echo "Found I2C devices: $(find /dev -path '/dev/i2c*' | xargs)" &&
	(echo "DAC+ detection: `i2cget -y 1 0x4d 40`" || true) &&
	backupBootConfig && # Make detect-hifiberry idempotent, allow restoring config.
	detect-hifiberry && # Writes /boot/config.txt eventually, configuring dtoverlay.
	writeHostAlsaConfigIfNotExist &&
	rebootIfBootConfigChanged &&
	echo ready > /tmp/ready &&
	terminate 0 'Configuration is ready' || terminate 1 'ERROR: Hifiberry auto-configuration failed' >&2
fi
