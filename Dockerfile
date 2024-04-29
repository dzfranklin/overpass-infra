FROM httpd

RUN apt update && apt install -y wget g++ make expat libexpat1-dev zlib1g-dev liblz4-dev curl

RUN wget "https://dev.overpass-api.de/releases/osm-3s_v0.7.62.tar.gz" -O release.tar.gz
RUN tar -xvzf release.tar.gz && mv osm-3s* /overpass
WORKDIR /overpass
RUN ./configure --enable-lz4
RUN make && chmod 755 bin/*.sh cgi-bin/*

RUN cp -pRT html /usr/local/apache2/htdocs && \
    cp -pRT cgi-bin /usr/local/apache2/cgi-bin

COPY httpd.conf /usr/local/apache2/conf/httpd.conf

COPY run.sh /

ENTRYPOINT ["/run.sh"]
