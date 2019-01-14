FROM quay.io/spivegin/golangnodesj AS build
RUN apt-get -y update && apt-get -y upgrade && \
    apt-get -y install git && apt-get -y autoremove && apt-get -y clean &&\
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
WORKDIR /opt/src/src/github.com/trh-docker/swirl
ADD . .
ENV GO111MODULE on
RUN CGO_ENABLED=0 go build -ldflags "-s -w"

FROM quay.io/spivegin/tlmbasedebian
WORKDIR /app
COPY --from=build /opt/src/src/github.com/trh-docker/swirl/swirl .
COPY --from=build /opt/src/src/github.com/trh-docker/swirl/config ./config/
COPY --from=build /opt/src/src/github.com/trh-docker/swirl/assets ./assets/
COPY --from=build /opt/src/src/github.com/trh-docker/swirl/views ./views/
EXPOSE 8001
ENTRYPOINT ["/app/swirl"]
