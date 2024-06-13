#!/bin/sh

IGNORE_MARKER_FILE=/host/boot/hifiberry-autoconfig.ignore

BOOT_CONFIG_FILE=/boot/config.txt
# On newer RaspiOS versions the boot config is at /boot/firmware/config.txt
[ ! -f /host/boot/firmware/config.txt ] || BOOT_CONFIG_FILE=/boot/firmware/config.txt

set -eu

isHostIgnorable() {
	[ -f $IGNORE_MARKER_FILE ]
}

markHostAsIgnorable() {
	# Let the script ignore subsequent invokations
	touch $IGNORE_MARKER_FILE
	sync
}

alsaDeviceDetected() {
	aplay -l | grep hifiberry | grep -q pcm5102
}

backupBootConfig() {
	BACKUP_FILE=${BOOT_CONFIG_FILE}.hifiberry-autoconf.bak
	if [ ! -f /host${BACKUP_FILE} ]; then
		echo "INFO: Creating ${BOOT_CONFIG_FILE} backup at ${BACKUP_FILE}"
		cp -f /host${BOOT_CONFIG_FILE} /host${BACKUP_FILE}.tmp
		mv /host${BACKUP_FILE}.tmp /host${BACKUP_FILE}
		sync
	else
		echo "INFO: Skipping ${BOOT_CONFIG_FILE} backup since it already exists at ${BACKUP_FILE}"
	fi
}

copyHostBootConfigIntoContainer() {
	mkdir -p /boot
	[ -f /boot/config.txt ] || cp /host${BOOT_CONFIG_FILE} /boot/config.txt
}

writeHostBootConfig() {
	echo 'INFO: Writing ${BOOT_CONFIG_FILE} to host'
	diff /boot/config.txt /host${BOOT_CONFIG_FILE} || true
	cp -f /boot/config.txt /host${BOOT_CONFIG_FILE}.tmp
	mv /host${BOOT_CONFIG_FILE}.tmp /host${BOOT_CONFIG_FILE}
	sync
}

writeHostALSAConfigIfNotExist() {
	if [ -d /host/etc ] && [ ! -f /host/etc/asound.conf ]; then
		echo 'INFO: Installing /etc/asound.conf on the host'
		cp -f /etc/asound.conf /host/etc/asound.conf.tmp &&
		mv /host/etc/asound.conf.tmp /host/etc/asound.conf &&
		sync
	fi
}

disableOnboardAudioDevices() {
	sed -Ei '/^dtparam=audio=on/d' /boot/config.txt &&
	sed -Ei 's/^dtoverlay=vc4-fkms-v3d$/dtoverlay=vc4-fkms-v3d,audio=off/' /boot/config.txt &&
	sed -Ei 's/^dtoverlay=vc4-kms-v3d$/dtoverlay=vc4-kms-v3d,noaudio/' /boot/config.txt
}

waitForI2CDevicesToBecomeAvailable() {
	I2S_INIT_TIMEOUT=30
	for _ in $(seq 1 $I2S_INIT_TIMEOUT); do
		sleep 1
		find /dev -path '/dev/i2c*' | grep -q . && return 0 || true
		echo 'INFO: Waiting for I2C device files to become available' >&2
	done
	echo "ERROR: Timed out waiting ${I2S_INIT_TIMEOUT}s for device files to become available" >&2
	return 1
}

printDeviceInfo() {
	echo "INFO: I2C devices: $(find /dev -path '/dev/i2c*' | xargs)"
	echo 'INFO: ALSA devices:'
	aplay -l | grep -E '^card ' | sed -E 's/^/INFO:   /'
}

rebootMaybe() {
	if [ "$REBOOT_ON_CHANGE" = true ]; then
		echo 'INFO: Rebooting the system'
		sleep 3
		kill -2 1
	else
		echo 'INFO: Skipping reboot since REBOOT_ON_CHANGE=false'
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

if isHostIgnorable; then
	printDeviceInfo &&
	echo ready > /tmp/ready &&
	terminate 0 "INFO: Skipping HiFiBerry auto-configuration since file $IGNORE_MARKER_FILE exists"
elif alsaDeviceDetected; then
	printDeviceInfo &&
	echo ready > /tmp/ready &&
	terminate 0 'INFO: Skipping HiFiBerry auto-configuration since ALSA device found'
else
	echo 'INFO: Detecting HiFiBerry I2C device ...'
	modprobe i2c-dev &&
	waitForI2CDevicesToBecomeAvailable &&
	printDeviceInfo &&
	backupBootConfig &&
	copyHostBootConfigIntoContainer &&
	(detect-hifiberry || (cat /var/log/hifiberry.log 2>/dev/null; false)) && # Writes /boot/config.txt eventually, configuring dtoverlay.
	disableOnboardAudioDevices &&
	writeHostALSAConfigIfNotExist &&
	writeHostBootConfig &&
	markHostAsIgnorable &&
	rebootMaybe &&
	echo ready > /tmp/ready &&
	terminate 0 'INFO: Configuration is ready' || terminate 1 'ERROR: HiFiBerry auto-configuration failed' >&2
fi
