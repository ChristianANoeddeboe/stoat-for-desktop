#!/bin/sh
# Keep /data/repo in sync with the .deb files on the latest GitHub release.
#   update-repo init  create the signing key (once) and build the index
#   update-repo sync  fetch new packages and rebuild the index if anything changed
#   update-repo loop  sync every $INTERVAL seconds
set -eu

REPO_DIR=/data/repo
POOL=$REPO_DIR/pool/main
DIST=$REPO_DIR/dists/stable
export GNUPGHOME=/data/gnupg

log() { echo "[update-repo] $*"; }

ensure_key() {
    mkdir -p "$GNUPGHOME" "$POOL"
    chmod 700 "$GNUPGHOME"
    if [ -z "$(gpg --batch --list-secret-keys --with-colons 2>/dev/null)" ]; then
        log "generating signing key"
        gpg --batch --passphrase '' --quick-gen-key "Stoat Desktop apt repository" ed25519 sign never
    fi
    gpg --batch --yes --export -o "$REPO_DIR/stoat.gpg"
}

build_index() {
    log "building index"
    tmp=$(mktemp -d)
    mkdir -p "$tmp/main/binary-amd64"
    (cd "$REPO_DIR" && apt-ftparchive packages pool) > "$tmp/main/binary-amd64/Packages"
    gzip -9 -k "$tmp/main/binary-amd64/Packages"
    apt-ftparchive \
        -o APT::FTPArchive::Release::Origin="Stoat" \
        -o APT::FTPArchive::Release::Label="Stoat Desktop" \
        -o APT::FTPArchive::Release::Suite="stable" \
        -o APT::FTPArchive::Release::Codename="stable" \
        -o APT::FTPArchive::Release::Architectures="amd64" \
        -o APT::FTPArchive::Release::Components="main" \
        release "$tmp" > "$tmp/Release"
    gpg --batch --yes --clearsign -o "$tmp/InRelease" "$tmp/Release"
    gpg --batch --yes -abs -o "$tmp/Release.gpg" "$tmp/Release"

    # Swap the whole dist in at once so clients never see a half written index
    chmod -R a+rX "$tmp"
    mkdir -p "$REPO_DIR/dists"
    rm -rf "$DIST.old"
    [ -d "$DIST" ] && mv "$DIST" "$DIST.old"
    mv "$tmp" "$DIST"
    rm -rf "$DIST.old"
}

sync_release() {
    changed=0
    release=$(curl -fsSL "https://api.github.com/repos/$GITHUB_REPO/releases/latest") || {
        log "could not reach GitHub"
        return 0
    }

    for entry in $(printf "%s" "$release" | jq -r '.assets[] | select(.name | endswith("_amd64.deb")) | "\(.name)|\(.browser_download_url)"'); do
        name=${entry%%|*}
        url=${entry#*|}
        [ -f "$POOL/$name" ] && continue

        log "downloading $name"
        if curl -fsSL -o "$POOL/$name.part" "$url"; then
            mv "$POOL/$name.part" "$POOL/$name"
            changed=1
        else
            rm -f "$POOL/$name.part"
            log "download failed: $name"
        fi
    done

    # Keep the newest $KEEP packages so a downgrade is possible
    for old in $(ls -1t "$POOL"/*.deb 2>/dev/null | tail -n +$((KEEP + 1))); do
        log "pruning ${old##*/}"
        rm -f "$old"
        changed=1
    done

    if [ "$changed" = 1 ] || [ ! -f "$DIST/InRelease" ]; then
        build_index
    fi
}

case "${1:-sync}" in
    init)
        ensure_key
        sync_release
        ;;
    sync)
        sync_release
        ;;
    loop)
        while sleep "$INTERVAL"; do
            sync_release || log "sync failed"
        done
        ;;
    *)
        echo "usage: $0 init|sync|loop" >&2
        exit 1
        ;;
esac
