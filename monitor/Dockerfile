FROM golang as build

WORKDIR /build

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go build .

FROM debian:bookworm-slim

COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /build/monitor /monitor

ENTRYPOINT ["/monitor"]
