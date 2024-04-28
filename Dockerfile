FROM ubuntu:latest

RUN apt update && apt install -y wget g++ make expat libexpat1-dev zlib1g-dev liblz4-dev

RUN wget "https://dev.overpass-api.de/releases/osm-3s_v0.7.62.tar.gz" -O release.tar.gz
RUN tar -xvzf release.tar.gz && mv osm-3s* /overpass
WORKDIR /overpass
RUN ./configure --enable-lz4
RUN make && chmod 755 bin/*.sh cgi-bin/*

COPY ./my_dispatcher.sh /overpass/bin/
COPY ./my_updater.sh /overpass/bin/
