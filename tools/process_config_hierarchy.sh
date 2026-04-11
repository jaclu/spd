#!/bin/sh

#=====================================================================
#
#   Main
#
#=====================================================================

echo "><> processing process_config_hierarchy"
[ -n "$DEPLOY_PATH" ] || {
    #  Run this in stand-alone mode
    DEPLOY_PATH=$(cd -- "$(dirname -- "$0")/.." && pwd)
    . "$DEPLOY_PATH"/tools/prepare_env.sh
}

source_it "$DEPLOY_PATH"/tools/process_config_file.sh
read_config_file "$DEPLOY_PATH"/config_templates/defaults.yml

# shellcheck disable=SC2034
SPD_CONFIG_PROCESSED="Done by: $0"
