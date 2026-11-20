#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verify="$script_dir/../Verify-Package.sh"
sh "$script_dir/../Prepare-Verification.sh"
temporary=$(mktemp -d)
. "$script_dir/../verification-tools.sh"
corrupt_cache="$temporary/corrupt-cache/production-output-verification/jq-$jq_version"
trap 'rm -f "$temporary/package.json" "$corrupt_cache/$jq_asset"; if test -d "$corrupt_cache"; then rmdir "$corrupt_cache" "$temporary/corrupt-cache/production-output-verification" "$temporary/corrupt-cache"; fi; rmdir "$temporary"' EXIT HUP INT TERM
checks=0

check() {
    expected=$1
    json=$2
    description=$3
    printf '%s' "$json" > "$temporary/package.json"
    if sh "$verify" "$temporary/package.json" >/dev/null 2>&1; then
        actual=pass
    else
        actual=fail
    fi
    if test "$actual" != "$expected"; then
        echo "Unexpected $actual: $description" >&2
        exit 1
    fi
    checks=$((checks + 1))
}

check pass '{"name":"production-output","version":"0.1.0","private":true}' 'minimal private package'
check pass '{"private":true,"version":"1.2.3-rc.1+build.7","name":"@factory/output"}' 'scoped name and prerelease version'
check pass '{"name":"output","version":"1.0.0","private":true,"description":"Output project"}' 'non-executable optional metadata'
check fail '{"name":"output","version":"1.0.0"}' 'missing private'
check fail '{"name":"output","version":"1.0.0","private":false}' 'non-private package'
check fail '{"name":"output","version":"1.0.0","private":"true"}' 'string is not boolean'
check fail '{"name":"output","version":"1.0.0","private":true,"dependencies":{}}' 'dependencies even when empty'
check fail '{"name":"output","version":"1.0.0","private":true,"devDependencies":{}}' 'devDependencies even when empty'
check fail '{"name":"output","version":"1.0.0","private":true,"scripts":{}}' 'scripts even when empty'
check fail '{"name":"Output","version":"1.0.0","private":true}' 'uppercase name'
check fail '{"name":"https://example.invalid/output","version":"1.0.0","private":true}' 'name is not a repository URL'
check fail '{"name":"output","version":"01.0.0","private":true}' 'version with leading zero'
check fail '{"name":"output","version":"1.0.0-01","private":true}' 'numeric prerelease with leading zero'
check fail '{"name":"output","version":"1.0","private":true}' 'incomplete version'
check fail '{"name":"output","version":"1.0.0","private":false,"private":true}' 'duplicate required field'
check fail '[{"name":"output","version":"1.0.0","private":true}]' 'array is not a package object'
check fail 'null' 'null is not a package object'
check fail '{"name":"output","version":"1.0.0","private":true} {}' 'multiple JSON documents'
check fail '{"name":"output",' 'invalid JSON'
if sh "$verify" "$temporary/missing.json" >/dev/null 2>&1; then
    echo 'A missing manifest must fail verification.' >&2
    exit 1
fi
checks=$((checks + 1))
check fail "$(printf '%65536s' '')"'{"name":"output","version":"1.0.0","private":true}' 'oversized manifest'
printf '%s' '{"name":"output","version":"1.0.0","private":true}' > "$temporary/package.json"
if XDG_CACHE_HOME="$temporary/missing-cache" sh "$verify" "$temporary/package.json" >/dev/null 2>&1; then
    echo 'Verification without prepared tools must fail.' >&2
    exit 1
fi
checks=$((checks + 1))
mkdir -p "$corrupt_cache"
cp "$jq_path" "$corrupt_cache/$jq_asset"
printf '%s' 'checksum corruption' >> "$corrupt_cache/$jq_asset"
chmod 755 "$corrupt_cache/$jq_asset"
reject_corrupt() {
    if XDG_CACHE_HOME="$temporary/corrupt-cache" sh "$@" >/dev/null 2>&1; then
        echo 'A corrupted cached verifier must fail, not be executed or silently replaced.' >&2
        exit 1
    fi
    checks=$((checks + 1))
}
reject_corrupt "$verify" "$temporary/package.json"
reject_corrupt "$script_dir/../Prepare-Verification.sh"
echo "Passed $checks focused package verification assertions."
