# TODO: Clean log files <https://github.com/drolbr/Overpass-API/issues/679>

FROM httpd
ARG S6_OVERLAY_VERSION=3.1.6.2

RUN apt update && apt install -y wget g++ make expat libexpat1-dev zlib1g-dev liblz4-dev curl xz-utils

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-arm.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-arm.tar.xz

RUN wget "https://dev.overpass-api.de/releases/osm-3s_v0.7.62.tar.gz" -O release.tar.gz
RUN tar -xvzf release.tar.gz && mv osm-3s* /overpass
WORKDIR /overpass
RUN ./configure --enable-lz4
RUN make && chmod 755 bin/*.sh cgi-bin/*

RUN cp -pRT html /usr/local/apache2/htdocs && \
    cp -pRT cgi-bin /usr/local/apache2/cgi-bin

COPY httpd.conf /usr/local/apache2/conf/httpd.conf

COPY s6-rc.d /etc/s6-overlay/s6-rc.d

# Reset as the httpd image changes this
STOPSIGNAL SIGTERM

ENV S6_KEEP_ENV=1

ENTRYPOINT ["/init"]
