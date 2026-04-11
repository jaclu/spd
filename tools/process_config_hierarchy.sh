#!/bin/sh

#=====================================================================
#
#   Main
#
#=====================================================================

# echo "><> processing process_config_hierarchy"
[ -n "$DEPLOY_PATH" ] || {
    #  Run this in stand-alone mode
    DEPLOY_PATH=$(cd -- "$(dirname -- "$0")/.." && pwd)
    . "$DEPLOY_PATH"/tools/prepare_env.sh
}

source_it "$DEPLOY_PATH"/tools/process_config_file.sh

read_config_file "$DEPLOY_PATH"/configs/defaults.yml
is_linux && read_config_file "$DEPLOY_PATH"/configs/platform/linux.yml
is_macos && read_config_file "$DEPLOY_PATH"/configs/platform/macos.yml
is_ish && read_config_file "$DEPLOY_PATH"/configs/platform/ish.yml
command -v apt >/dev/null && read_config_file "$DEPLOY_PATH"/configs/PktHandlers/pkg_apt.yml
command -v apk >/dev/null && read_config_file "$DEPLOY_PATH"/configs/PktHandlers/pkg_apk.yml
command -v brew >/dev/null && read_config_file "$DEPLOY_PATH"/configs/PktHandlers/pkg_homebrew.yml
read_config_file "$DEPLOY_PATH/configs/hostname/$(hostname -s | tr '[:upper:]' '[:lower:]').yml"
# shellcheck disable=SC2034
SPD_CONFIG_PROCESSED="Done by: $0"
