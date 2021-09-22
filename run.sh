#!/bin/sh -eux

docker pull ghcr.io/rekgrpth/smtp.docker
docker network create --attachable --opt com.docker.network.bridge.name=docker docker || echo $?
docker volume create smtp
docker stop smtp || echo $?
docker rm smtp || echo $?
docker run \
    --detach \
    --env GROUP_ID="$(id -g)" \
    --env LANG=ru_RU.UTF-8 \
    --env PGHOST=postgres \
    --env TZ=Asia/Yekaterinburg \
    --env USER_ID="$(id -u)" \
    --hostname smtp \
    --mount type=bind,source=/etc/certs,destination=/etc/certs,readonly \
    --mount type=volume,source=smtp,destination=/home \
    --name smtp \
    --network name=docker,alias=smtp."$(hostname -d)" \
    --restart always \
    ghcr.io/rekgrpth/smtp.docker
