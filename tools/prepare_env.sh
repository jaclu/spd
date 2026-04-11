#!/bin/sh

relative_path() { # Needed here due to: prepare_menu() - set_menu_env_variables()
    # remove D_TM_BASE_PATH prefix
    # log_it "relative_path($1) - removing prefix: $D_TM_BASE_PATH"
    printf '%s\n' "${1#"$DEPLOY_PATH"/}"
}

populate_config() {
    # If config/ is empty populate it with config_templates as a default
    _pc_d_conf="$DEPLOY_PATH"/configs
    [ -n "$(ls -A "$_pc_d_conf" 2>/dev/null)" ] || {
        _pc_d_templates="$DEPLOY_PATH"/config_templates
        lbl_1 "No configs found, populating $_pc_d_conf from templates"
        mkdir -p "$_pc_d_conf"
        cp -av "$_pc_d_templates"/* "$_pc_d_conf" || {
            error_msg "Failed to copy templates"
        }
    }
}

check_for_abort() {
    expand_config_var SPD_ABORT
    # shellcheck disable=SC2154 # SPD_ABORT defined in configs
    {
        # log_it "SPD_ABORT: $SPD_ABORT"
        [ "$SPD_ABORT" = 1 ] && err_msg "SPD_ABORT=1 prevents running on this host"
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

# echo "><> processing prepare_env"

[ -n "$DEPLOY_PATH" ] || {
    printf '\n%s[%s] ERROR: This can not be run directly.\n' "$0" "$$" >&2
    exit 1
}

load_utils
populate_config

log_it "prepare_env will process configs"
_fp="${DEPLOY_PATH}"/tools/process_config_hierarchy.sh
[ "$app_name_full_path" != "$_fp" ] && source_it "$_fp"
