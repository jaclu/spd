#!/bin/sh

populate_config() {
    # If config/ is empty populate it with config_templates as a default
    _pc_d_conf="$DEPLOY_PATH"/configs
    [ -n "$(ls -A "$_pc_d_conf" 2>/dev/null)" ] || {
        _pc_d_templates="$DEPLOY_PATH"/config_templates
        lbl_1 "No configs found, populating $_pc_d_conf from templates"
        mkdir -p "$_pc_d_conf"
        cp -a "$_pc_d_templates"/* "$_pc_d_conf" || {
            error_msg "Failed to copy templates"
        }
        echo
    }
}

load_utils() {
    _lu_f_utils="$DEPLOY_PATH"/tools/script-utils.sh
    [ -f "$_lu_f_utils" ] || {
        printf '\n%s[%s] ERROR: source file not found: %s\n' \
            "$0" "$$" "$_lu_f_utils" >&2
        exit 1
    }
    # shellcheck source=tools/script-utils.sh
    . "$_lu_f_utils"
    [ -n "$t_start" ] || {
        # guaranteed variable undefined, sourcing must have failed
        printf '\n%s[%s] ERROR: Sourcing %s failed to define: t_start\n' \
            "$0" "$$" "$_lu_f_utils" >&2
        exit 1
    }
}

#=====================================================================
#
#   Main
#
#=====================================================================

skip_auto_process_config_hierarchy=yes

DEPLOY_PATH=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=/dev/null
. "$DEPLOY_PATH"/tools/prepare_env.sh

#
# Test
#

. "$DEPLOY_PATH"/tools/process_config_file.sh

read_config_file "$DEPLOY_PATH"/configs/task_overrides/filesystem_alpine.yml
read_config_file "$DEPLOY_PATH"/debug/dummy_config.yml

echo "Verify variables retrieved"
# shellcheck disable=SC2154
{
    expand_config_var SPD_HOME_DIR_CONTENT
    expand_config_var SPD_UNAME

    eval foo=\$SPD_HOME_DIR_CONTENT
    echo "SPD_UNAME:            [$SPD_UNAME]"
    echo "SPD_HOME_DIR_CONTENT: [$SPD_HOME_DIR_CONTENT]"
    echo "SPD_NO_BLANKS:        [$SPD_NO_BLANKS]"
    echo "SPD_WITH_BLANKS:      [$SPD_WITH_BLANKS]"
    echo "SPD_APK_MAN:          [$SPD_APK_MAN]"
}
