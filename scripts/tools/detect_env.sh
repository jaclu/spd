#!/bin/sh
# shellcheck disable=SC2154
#
# Copyright (c) 2021: Jacob.Lundqvist@gmail.com 2022-07-11
# License: MIT
#
# Part of https://github.com/jaclu/spd
#

if test -z "$DEPLOY_PATH"; then
    # assumung 0 is in same dir when calculating depth
    DEPLOY_PATH=$(cd -- "$(dirname -- "$0")/../.." && pwd)
    echo "DEPLOY_PATH=$DEPLOY_PATH  detect_env.sh"
fi

# shellcheck disable=SC1091
. "$DEPLOY_PATH"/scripts/tools/utils.sh

detect_env
#
# show what was detected
#
echo
echo "Env detected"
echo "------------"
echo "      cfg_os_type: $cfg_os_type"
echo "       cfg_kernel: $cfg_kernel"
echo "cfg_distro_family: $cfg_distro_family"
echo "       cfg_distro: $cfg_distro"
echo
