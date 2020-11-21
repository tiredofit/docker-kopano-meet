FROM tiredofit/alpine:3.12 as meet-builder

ARG MEET_REPO_URL
ARG MEET_VERSION

ENV MEET_REPO_URL=${MEET_REPO_URL:-"https://github.com/Kopano-dev/meet"} \
    MEET_VERSION=${MEET_VERSION:-"v2.2.3"}

ADD build-assets/kopano-meet /build-assets

RUN set -x && \
    apk update && \
    apk upgrade && \
    apk add -t .meet-build-deps \
                build-base \
                coreutils \
                ffmpeg \
                gettext \
                git \
                nodejs \
                python3 \
                sox \
                tar \
                yarn \
                && \
    \
    ln -s /usr/bin/ffmpeg /usr/bin/avconv && \
    \
    git clone ${MEET_REPO_URL} /usr/src/meet && \
    cd /usr/src/meet && \
    git checkout ${MEET_VERSION} && \
    \
    if [ -d "/build-assets/src/app" ] ; then cp -R /build-assets/src/app/* /usr/src/meet ; fi; \
    if [ -f "/build-assets/scripts/meet-webapp.sh" ] ; then /build-assets/scripts/meet-webapp.sh ; fi; \
    \
    make && \
    mkdir -p /rootfs/usr/share/kopano-meet/meet-webapp/ && \
    cp -R ./build/* /rootfs/usr/share/kopano-meet/meet-webapp/ && \
    mkdir -p /rootfs/tiredofit && \
    echo "Kopano Meet ${MEET_VERSION} built from ${MEET_REPO_URL} on $(date)" > /rootfs/tiredofit/meet.version && \
    echo "Commit: $(cd /usr/src/meet ; echo $(git rev-parse HEAD))" >> /rootfs/tiredofit/meet.version && \
    cd /rootfs && \
    tar cvfz /kopano-meet.tar.gz . && \
    cd / && \
    apk del .meet-build-deps && \
    rm -rf /usr/src/* && \
    rm -rf /var/cache/apk/* && \
    rm -rf /rootfs

FROM tiredofit/nginx:latest
LABEL maintainer="Dave Conroy (dave at tiredofit dot ca)"

ENV ENABLE_SMTP=FALSE \
    NGINX_ENABLE_CREATE_SAMPLE_HTML=FALSE \
    NGINX_LOG_ACCESS_LOCATION=/logs/nginx \
    NGINX_LOG_ERROR_LOCATION=/logs/nginx \
    NGINX_WEBROOT=/usr/share/kopano-meet/meet-webapp/ \
    ZABBIX_HOSTNAME=meet-app

### Move Previously built files from builder image
COPY --from=meet-builder /*.tar.gz /usr/src/meet/

RUN set -x && \
    apk update && \
    apk upgrade && \
    \
    ##### Unpack Meet
    tar xvfz /usr/src/meet/kopano-meet.tar.gz -C / && \
    rm -rf /usr/src/* && \
    rm -rf /etc/kopano && \
    ln -sf /config /etc/kopano && \
    rm -rf /var/cache/apk/*

ADD install /
