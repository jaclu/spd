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
# echo "SPD_SVC_RUNBG_RUNLVL: $SPD_SVC_RUNBG_RUNLVL"
is_chrooted_ish && read_config_file "$DEPLOY_PATH"/configs/platform/ish.yml

# # Package handler
# command -v apk >/dev/null && read_config_file "$DEPLOY_PATH"/configs/file_systems/alpine.yml
# command -v brew >/dev/null && read_config_file "$DEPLOY_PATH"/configs/file_systems/pkg_homebrew.yml

# service related
# echo "post ish: SPD_SVC_RUNBG_RUNLVL: $SPD_SVC_RUNBG_RUNLVL"
read_config_file "$DEPLOY_PATH"/configs/services/autossh.yml
read_config_file "$DEPLOY_PATH"/configs/services/runbg.yml

# hostname specific
read_config_file "$DEPLOY_PATH/configs/hostname/$(hostname -s | tr '[:upper:]' '[:lower:]').yml"

msg_dbg "SPD_ABORT: $SPD_ABORT" 1

# shellcheck disable=SC2034
SPD_CONFIG_PROCESSED="Done by: $0"
