# Self-hosted apt repository for Stoat Desktop.
# Mirrors the .deb from the fork's latest GitHub release, signs the index with a
# key generated on first start, and serves it with nginx.
FROM nginx:1.29

RUN apt-get update \
    && apt-get install -y --no-install-recommends apt-utils gnupg curl jq ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY update-repo.sh /usr/local/bin/update-repo
COPY 99-update-repo.sh /docker-entrypoint.d/99-update-repo.sh
RUN chmod +x /usr/local/bin/update-repo /docker-entrypoint.d/99-update-repo.sh

ENV GITHUB_REPO=ChristianANoeddeboe/stoat-for-desktop \
    INTERVAL=900 \
    KEEP=3

VOLUME ["/data"]
