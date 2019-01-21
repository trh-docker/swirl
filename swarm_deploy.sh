#!/usr/bin/env bash

CHANGE_TO_NODE_NAME=$1
CHANGE_TO_YOUR_ACCESS_KEY=$2
CHANGE_TO_YOUR_SECRET_KEY=$3
DOMAIN=$4
docker node update --label-add minio=true ${CHANGE_TO_NODE_NAME}
echo "${CHANGE_TO_YOUR_ACCESS_KEY}" | docker secret create access_key - > access_key.txt
echo "${CHANGE_TO_YOUR_SECRET_KEY}" | docker secret create secret_key - > secret_key.txt

cat << EOF >> swirl_install.docker-compose.yml
version: '3.7'

services:
  traefik:
    image: quay.io/spivegin/tricllproxy
    command: --web --docker --providers.docker.swarmmode --docker.watch --docker.domain=${DOMAIN} --logLevel=DEBUG
    ports:
      - "80:80"
      - "8080:8080"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /dev/null:/traefik.toml
    labels:
      - "traefik.enable=false"
    networks:
      - adfree-net
    deploy:
      replicas: 3
      placement:
        constraints: [node.role==manager]
      restart_policy:
        condition: on-failure
      command:
      secrets:
        - secret_key
        - access_key
  swirl:
    image: quay.io/spivegin/tricllswirl
    environment:
      DB_ADDRESS: mongo:27017/swirl
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - net
      - adfree-net
    deploy:
      replicas: 1
      labels:
        - "traefik.port=8001"
        - "traefik.docker.network=adfree-net"
        - "traefik.frontend.rule=Host:s.${DOMAIN}"
        - "traefik.backend.loadbalancer.sticky=true"
      placement:
        constraints:
          - node.role==manager
    minio1:
      image: minio/minio:RELEASE.2019-01-10T00-21-20Z
      hostname: minio1
      volumes:
        - minio1-data:/export
      networks:
        - adfree-net
      deploy:
        restart_policy:
          delay: 10s
          max_attempts: 10
          window: 60s
        placement:
          constraints:
            - node.labels.minio==true
        labels:
          - "traefik.port=9000"
          - "traefik.docker.network=adfree-net"
          - "traefik.frontend.rule=Host:m.example.com"
          - "traefik.backend.loadbalancer.sticky=true"
      command: server http://minio1/export
      secrets:
        - secret_key
        - access_key

  mongo:
    image: mongo
    volumes:
      - mongo:/data/db
    networks:
      - net
    deploy:
      replicas: 1
volumes:
  mongo:

networks:
  net:
  adfree-net:
    driver: overlay
secrets:
  secret_key:
    external: true
  access_key:
    external: true
EOF


docker stack deploy --compose-file=swirl_install.docker-compose.yml swirl


#if [ ! -f /etc/webmin/miniserv.conf ]; then
#    mv /etc/webmin/miniserv.conf /etc/webmin/miniserv.conf.distro
#fi
