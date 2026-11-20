jq_version=1.8.2
case "$(uname -s)" in
    Linux)
        test "$(uname -m)" = x86_64 || { echo 'Verification requires Linux x64.' >&2; exit 1; }
        jq_asset=jq-linux-amd64
        jq_sha256=b1c22172dd303f3be49e935aa56aa48a8b7a46e0bc838b4997d3bb451495870f
        ;;
    MINGW*|MSYS*)
        test "$(uname -m)" = x86_64 || { echo 'Authoring checks require Windows x64.' >&2; exit 1; }
        jq_asset=jq-windows-amd64.exe
        jq_sha256=a6fc67fedaf9128a3309a1e2ebb8b986aeccf70122ee46d2cb4849e423f0c627
        ;;
    *)
        echo 'Unsupported verification platform; use Linux x64 or Git for Windows x64.' >&2
        exit 1
        ;;
esac
jq_cache="${XDG_CACHE_HOME:-"${HOME:?HOME must be configured}/.cache"}/production-output-verification/jq-$jq_version"
jq_path="$jq_cache/$jq_asset"
jq_url="https://github.com/jqlang/jq/releases/download/jq-$jq_version/$jq_asset"

require_jq() {
    if ! test -f "$jq_path" || test -L "$jq_path" || ! test -x "$jq_path"; then
        echo 'Run productionLine/Prepare-Verification.sh before verification.' >&2
        return 1
    fi
    actual=$(sha256sum "$jq_path") || return 1
    if test "${actual%% *}" != "$jq_sha256"; then
        echo "Verification tool checksum mismatch: $jq_path" >&2
        return 1
    fi
    if test "$("$jq_path" --version)" != "jq-$jq_version"; then
        echo 'Verification tool version mismatch.' >&2
        return 1
    fi
}
