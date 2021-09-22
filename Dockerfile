FROM ghcr.io/rekgrpth/gost.docker
WORKDIR "${HOME}"
ENV GROUP=smtpd \
    USER=smtpd
RUN set -eux; \
    apk update --no-cache; \
    apk upgrade --no-cache; \
    apk add --no-cache --virtual .build-deps \
        autoconf \
        automake \
        gawk \
        gcc \
        gettext-dev \
        git \
        libtool \
        make \
        musl-dev \
        postgresql-dev \
        texinfo \
    ; \
    mkdir -p "${HOME}/src"; \
    cd "${HOME}/src"; \
    git clone -b master https://github.com/RekGRpth/gawkextlib.git; \
    cd "${HOME}/src/gawkextlib/lib"; \
    autoreconf -vif; \
    ./configure; \
    make -j"$(nproc)" install; \
    cd "${HOME}/src/gawkextlib/pgsql"; \
    autoreconf -vif; \
    ./configure; \
    make -j"$(nproc)" install; \
    cd /; \
    apk add --no-cache --virtual .postgresql-rundeps \
        gawk \
        opensmtpd \
        $(scanelf --needed --nobanner --format '%n#p' --recursive /usr/local | tr ',' '\n' | sort -u | while read -r lib; do test ! -e "/usr/local/lib/$lib" && echo "so:$lib"; done) \
    ; \
    find /usr/local/bin -type f -exec strip '{}' \;; \
    find /usr/local/lib -type f -name "*.so" -exec strip '{}' \;; \
    apk del --no-cache .build-deps; \
    find /usr -type f -name "*.a" -delete; \
    find /usr -type f -name "*.la" -delete; \
    rm -rf "${HOME}" /usr/share/doc /usr/share/man /usr/local/share/doc /usr/local/share/man; \
    sed -i 's|table aliases|#table aliases|g' /etc/smtpd/smtpd.conf; \
    sed -i 's|listen on lo|listen on 0.0.0.0|g' /etc/smtpd/smtpd.conf; \
    sed -i 's|action "local" maildir alias|#action "local" maildir alias|g' /etc/smtpd/smtpd.conf; \
    sed -i 's|match from local for any action "relay"|match from any for any action "relay"|g' /etc/smtpd/smtpd.conf; \
    sed -i 's|match for local action "local"|#match for local action "local"|g' /etc/smtpd/smtpd.conf; \
    echo done
