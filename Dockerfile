FROM debian:bookworm-slim AS eepromutils
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update
RUN apt-get install -y git make gcc libc-dev
RUN git clone https://github.com/raspberrypi/hats.git
WORKDIR /hats/eepromutils
RUN make

FROM debian:bookworm-slim
ENV HIFIBERRYOS_VERSION=v20221128 \
	KEEP_RUNNING=false \
	REBOOT_ON_CHANGE=false
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y bash alsa-utils sox i2c-tools wget
RUN set -eux; \
	mkdir -p /opt/hifiberry/bin; \
	wget -qO /opt/hifiberry/bin/detect-hifiberry https://raw.githubusercontent.com/hifiberry/hifiberry-os/${HIFIBERRYOS_VERSION}/buildroot/package/hifiberry-tools/detect-hifiberry; \
	chmod +x /opt/hifiberry/bin/detect-hifiberry; \
	wget -qO /opt/hifiberry/bin/readhat https://raw.githubusercontent.com/hifiberry/hifiberry-os/${HIFIBERRYOS_VERSION}/buildroot/package/hifiberry-tools/readhat; \
	chmod +x /opt/hifiberry/bin/readhat; \
	wget -qO /opt/hifiberry/LICENSE https://raw.githubusercontent.com/hifiberry/hifiberry-os/${HIFIBERRYOS_VERSION}/LICENSE; \
	printf '#!/bin/true\necho mount skipped' > /usr/local/bin/mount; \
	chmod +x /usr/local/bin/mount; \
	ln -s /opt/hifiberry/bin/detect-hifiberry /bin/detect-hifiberry
COPY --from=eepromutils /hats/eepromutils/eepdump /usr/bin/eepdump
RUN eepdump --help
COPY asound.conf /etc/asound.conf
COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
