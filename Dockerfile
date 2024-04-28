FROM ubuntu:latest AS build

RUN apt update && apt install -y wget g++ make expat libexpat1-dev zlib1g-dev

RUN wget "https://dev.overpass-api.de/releases/osm-3s_v0.7.62.tar.gz" -O release.tar.gz
RUN tar -xvzf release.tar.gz && mv osm-3s* release
WORKDIR /release
RUN ./configure && make && chmod 755 bin/*.sh cgi-bin/*

FROM ubuntu:latest

COPY --from=build /release /overpass
