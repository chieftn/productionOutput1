#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/verification-tools.sh"
require_jq
if test "$#" -gt 1; then
    echo 'Usage: sh productionLine/Verify-Package.sh [manifest-path]' >&2
    exit 1
fi
file=${1:-"$script_dir/../package.json"}
if ! test -f "$file" || test -L "$file"; then
    echo "A regular, non-linked package manifest is required: $file" >&2
    exit 1
fi
if test "$(wc -c < "$file")" -gt 65536; then
    echo 'The minimal package manifest must not exceed 64 KiB.' >&2
    exit 1
fi
if ! "$jq_path" --stream --slurp --exit-status \
    'map(select(length == 2) | .[0]) | length == (unique | length)' "$file" >/dev/null; then
    echo 'Package JSON must parse without duplicate value paths.' >&2
    exit 1
fi
if ! "$jq_path" --slurp --exit-status --from-file "$script_dir/package-check.jq" "$file" >/dev/null; then
    echo 'Expected one package object with a valid lowercase name, SemVer version, private: true, and no dependencies/devDependencies/scripts.' >&2
    exit 1
fi
echo "Verified private package manifest: $file"
