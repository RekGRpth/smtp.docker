FROM alpine:latest
ADD bin /usr/local/bin
ENTRYPOINT [ "docker_entrypoint.sh" ]
ENV HOME=/home
MAINTAINER RekGRpth
WORKDIR "$HOME"
CMD [ "smtpd", "-d" ]
ENV GROUP=smtpd \
    USER=smtpd
RUN set -eux; \
    ln -fs su-exec /sbin/gosu; \
    chmod +x /usr/local/bin/*.sh; \
    apk update --no-cache; \
    apk upgrade --no-cache; \
    apk add --no-cache --virtual .build \
        autoconf \
        automake \
        file \
        gawk \
        gcc \
        gettext-dev \
        git \
        libpq-dev \
        libtool \
        make \
        musl-dev \
        texinfo \
    ; \
    mkdir -p "$HOME/src"; \
    cd "$HOME/src"; \
    git clone -b master https://github.com/RekGRpth/gawkextlib.git; \
    cd "$HOME/src/gawkextlib/lib"; \
    autoreconf -vif; \
    ./configure; \
    make -j"$(nproc)" install; \
    cd "$HOME/src/gawkextlib/pgsql"; \
    autoreconf -vif; \
    ./configure --with-libpq="$(pg_config --includedir)"; \
    make -j"$(nproc)" install; \
    cd /; \
    apk add --no-cache --virtual .smtp \
        busybox-extras \
        busybox-suid \
        ca-certificates \
        gawk \
        musl-locales \
        opensmtpd \
        shadow \
        su-exec \
        tzdata \
        $(scanelf --needed --nobanner --format '%n#p' --recursive /usr/local | tr ',' '\n' | grep -v "^$" | grep -v -e libcrypto | sort -u | while read -r lib; do test -z "$(find /usr/local/lib -name "$lib")" && echo "so:$lib"; done) \
    ; \
    find /usr/local/bin -type f -exec strip '{}' \;; \
    find /usr/local/lib -type f -name "*.so" -exec strip '{}' \;; \
    apk del --no-cache .build; \
    rm -rf "$HOME" /usr/share/doc /usr/share/man /usr/local/share/doc /usr/local/share/man; \
    find /usr -type f -name "*.la" -delete; \
    mkdir -p "$HOME"; \
    chown -R "$USER":"$GROUP" "$HOME"; \
    echo done
ADD smtpd /etc/smtpd
