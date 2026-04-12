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
    # shellcheck source=tools/prepare_env.sh
    . "$DEPLOY_PATH"/tools/prepare_env.sh
}

source_it "$DEPLOY_PATH"/tools/process_config_file.sh

read_config_file "$DEPLOY_PATH"/configs/defaults.yml

# platform remated
is_linux && read_config_file "$DEPLOY_PATH"/configs/platform/linux.yml
is_macos && read_config_file "$DEPLOY_PATH"/configs/platform/macos.yml
is_chrooted_ish && read_config_file "$DEPLOY_PATH"/configs/platform/ish.yml

# file system related
fs_is_alpine && read_config_file "$DEPLOY_PATH"/configs/file_systems/alpine.yml
fs_is_debian && read_config_file "$DEPLOY_PATH"/configs/file_systems/debian.yml
fs_is_devuan && read_config_file "$DEPLOY_PATH"/configs/file_systems/devuan.yml
fs_is_ubuntu && read_config_file "$DEPLOY_PATH"/configs/file_systems/ubuntu.yml

# service related
read_config_file "$DEPLOY_PATH"/configs/services/autossh.yml
read_config_file "$DEPLOY_PATH"/configs/services/runbg.yml

# hostname specific
read_config_file "$DEPLOY_PATH/configs/hostname/$(hostname -s | tr '[:upper:]' '[:lower:]').yml"

# shellcheck disable=SC2034 # SPD_CONFIG_PROCESSED used by caller to determine if this has been run
SPD_CONFIG_PROCESSED="Done by: $0"
