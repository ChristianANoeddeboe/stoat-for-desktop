#!/bin/sh
# Run by the nginx image entrypoint before nginx starts: build the repo once, then keep it in sync
set -eu
/usr/local/bin/update-repo init
/usr/local/bin/update-repo loop &
