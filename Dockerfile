FROM alpine:3.17
ENV HIFIBERRYOS_VERSION=v20221128
RUN set -eux; \
	apk add --update --no-cache bash alsa-utils sox; \
	wget -O /bin/detect-hifiberry https://raw.githubusercontent.com/hifiberry/hifiberry-os/${HIFIBERRYOS_VERSION}/buildroot/package/hifiberry-tools/detect-hifiberry; \
	chmod +x /bin/detect-hifiberry; \
	wget -O /bin/readhat https://raw.githubusercontent.com/hifiberry/hifiberry-os/${HIFIBERRYOS_VERSION}/buildroot/package/hifiberry-tools/readhat; \
	chmod +x /bin/readhat
COPY asound.conf /etc/asound.conf
COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
