#!/bin/sh

handle_initd_script() {

    # shell check disable=SC2154
    case "$opt_task" in
        install)
            # shellcheck disable=SC2154 # _svc_init_scr_org defined in svc_handler_common.sh
            cp "$_svc_init_scr_org" "$svc_script" || {
                err_msg "$module_name: Failed to copy $_svc_init_scr_org"
            }
            ;;
        remove)
            if [ -f "$svc_script" ]; then
                safe_remove --ignore-sys-path "$svc_script" && {
                    log_3 "module_name: Removal of service script completed - svc_script"
                }
            else
                log_3 "module_name: svc_script not present"
            fi
            ;;
        *) ;;
    esac

}

handler_openrc() {
    # shellcheck disable=SC2154 # SPD_SVC_AUTOSSH_RUNLVL defined in openrc_dependency_check()
    svc_runlevel_set "$(basename "$svc_script")" "$SPD_SVC_RUNBG_RUNLVL"
}

handler_sysv() {
    case "$opt_task" in
        install)
            ln -sf "$svc_script" /etc/rc0.d/K01runbg
            ln -sf "$svc_script" /etc/rc1.d/K01runbg
            ln -sf "$svc_script" /etc/rc6.d/K01runbg

            ln -sf "$svc_script" /etc/rc2.d/S01runbg
            ln -sf "$svc_script" /etc/rc3.d/S01runbg
            ln -sf "$svc_script" /etc/rc4.d/S01runbg
            ln -sf "$svc_script" /etc/rc5.d/S01runbg
            ;;
        remove) safe_remove /etc/rc?.d/*runbg ;;
        *) err_msg "handler_sysv() unrecognized option: [$opt_task]" ;;
    esac
}

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"
    dependency_issue=0
    svc_script=/etc/init.d/runbg

    lbl_2 "$module_name: Preparing task"
    check_for_abort 1 task_prepare

    [ -n "$SPD_SERVICE_HANDLER" ] && {
        check_service_env runbg
        [ "$SPD_SERVICE_HANDLER" = openrc ] && {
            source_it "$D_REPO"/tools/svc_handler_openrc.sh
            openrc_dependency_check
        }
    }
    return "$dependency_issue"
}

task_execute() {
    # current_dbg_lvl=2
    lbl_2 "$module_name: Executing task"
    check_for_abort 0 task_execute

    handle_initd_script "$opt_task"

    # attach service to handler
    case "$SPD_SERVICE_HANDLER" in
        'openrc') handler_openrc ;;
        'sysv-init') handler_sysv ;;
        *) err_msg "$module_name: Unrecognized service-handler: $SPD_SERVICE_HANDLER" ;;
    esac
}

#=====================================================================
#
#   Main
#
#=====================================================================

module_name="service_runbg.sh"

[ -n "$D_REPO" ] || {
    #  Run this in stand-alone mode
    D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
    # shellcheck source=tools/prepare_env.sh
    . "$D_REPO"/tools/prepare_env.sh
}

# Ensure opions are valid
case "$opt_task" in
    install | remove) ;;
    *)
        cmd_line_param_error "$module_name: opt_task must be install/remove"
        ;;
esac

source_it "$D_REPO"/tools/svc_handler_common.sh

read_config_file "$D_REPO"/configs/services/unbg.yml
read_config_file "$D_REPO"/configs/task_overrides/service_runbg.yml
read_config_file "$D_REPO"/configs/global_overrides.yml # local user overrides

ensure_spd_var_defined SPD_SERVICE_HANDLER
# expand_config_var SPD_ABORT

task_prepare && task_execute
