#!/bin/sh

if command -v mtr; then
    [ "$(mtr -v)" = "mtr 0.91.1-4c982" ] && {
        exit 0 # correct "old" version installed
    }
    # Remove incorrect version
    apk del mtr || exit 30
fi
#
#  Download and install specific older mtr
#
d_tmp="$(mktemp -d -t mtr-retrieval)" || exit 31
cd "$d_tmp" || exit 32
url_prefix="https://dl-cdn.alpinelinux.org/alpine/v3.10/main/x86"
wget "$url_prefix"/mtr-0.92-r0.apk || exit 33
wget "$url_prefix"/mtr-doc-0.92-r0.apk || exit 34
apk add mtr-0.92-r0.apk mtr-doc-0.92-r0.apk || exit 35
rm -rf "$d_tmp" || exit 36
exit 43
