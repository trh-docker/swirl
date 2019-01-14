FROM quay.io/spivegin/golangnodesj AS build
RUN apk add git
WORKDIR /opt/src/src/github.com/trh-docker/swirl
ADD . .
ENV GO111MODULE on
RUN CGO_ENABLED=0 go build -ldflags "-s -w"

FROM quay.io/spivegin/tlmbasedebian
WORKDIR /app
RUN apk add --no-cache ca-certificates
COPY --from=build /opt/src/src/github.com/trh-docker/swirl/swirl .
COPY --from=build /opt/src/src/github.com/trh-docker/swirl/config ./config/
COPY --from=build /opt/src/src/github.com/trh-docker/swirl/assets ./assets/
COPY --from=build /opt/src/src/github.com/trh-docker/swirl/views ./views/
EXPOSE 8001
ENTRYPOINT ["/app/swirl"]
