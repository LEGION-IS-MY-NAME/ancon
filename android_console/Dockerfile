# syntax=docker/dockerfile:1
ARG BUILD_FROM
FROM ${BUILD_FROM}

ARG WS_SCRCPY_COMMIT

ENV LANG=C.UTF-8 \
    WS_SCRCPY_HOME=/opt/ws-scrcpy \
    NODE_ENV=production \
    PATH="/usr/local/bin:${PATH}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        android-tools-adb \
        ca-certificates \
        curl \
        git \
        gnupg \
        jq \
        nginx \
        nodejs \
        npm \
        python3 \
        make \
        g++ \
    && npm config set fund false \
    && npm config set update-notifier false \
    && rm -rf /var/lib/apt/lists/*

WORKDIR ${WS_SCRCPY_HOME}

RUN git init . \
    && git remote add origin https://github.com/NetrisTV/ws-scrcpy.git \
    && git fetch --depth 1 origin ${WS_SCRCPY_COMMIT} \
    && git checkout FETCH_HEAD \
    && npm ci --legacy-peer-deps \
    && npm run dist \
    && npm cache clean --force

COPY ingress.conf /etc/nginx/conf.d/ingress.conf
COPY rootfs /

RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chmod +x /etc/services.d/app/run \
    && chmod +x /etc/services.d/nginx/run

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 CMD curl -sf http://127.0.0.1:3000/ || exit 1
