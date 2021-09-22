#!/bin/sh -eux

docker pull ghcr.io/rekgrpth/postgres.docker
docker network create --attachable --opt com.docker.network.bridge.name=docker docker || echo $?
docker volume create postgres
docker stop postgres || echo $?
docker rm postgres || echo $?
docker run \
    --detach \
    --env GROUP_ID="$(id -g)" \
    --env LANG=ru_RU.UTF-8 \
    --env TZ=Asia/Yekaterinburg \
    --env USER_ID="$(id -u)" \
    --hostname postgres \
    --mount type=bind,source=/etc/certs,destination=/etc/certs,readonly \
    --mount type=bind,source=/run/postgresql,destination=/run/postgresql \
    --mount type=volume,source=postgres,destination=/var/lib/postgresql \
    --name postgres \
    --network name=docker,alias=postgres."$(hostname -d)" \
    --publish target=5432,published=5432,mode=host \
    --restart always \
    ghcr.io/rekgrpth/postgres.docker runsvdir /etc/service
