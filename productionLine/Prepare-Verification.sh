#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/verification-tools.sh"
if test -e "$jq_path" || test -L "$jq_path"; then
    require_jq
    echo "Verification tool ready: jq-$jq_version"
    exit 0
fi
mkdir -p "$jq_cache"
if test -L "$jq_cache"; then
    echo 'Verification cache must not be a symbolic link.' >&2
    exit 1
fi
download=$(mktemp "$jq_cache/.download.XXXXXX")
trap 'rm -f "$download"' EXIT HUP INT TERM
curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
    --connect-timeout 15 --max-time 120 --output "$download" "$jq_url"
actual=$(sha256sum "$download")
if test "${actual%% *}" != "$jq_sha256"; then
    echo 'Downloaded verification tool checksum does not match the pinned release.' >&2
    exit 1
fi
chmod 755 "$download"
mv -f "$download" "$jq_path"
require_jq
echo "Verification tool ready: jq-$jq_version"
