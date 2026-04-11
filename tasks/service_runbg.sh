#!/bin/sh

deploy_initd_script() {
    # shellcheck disable=SC2154 # _svc_init_scr_org defined in svc_handler_common.sh
    cp "$_svc_init_scr_org" "$svc_script" || {
        err_msg "$module_name: Failed to copy $_svc_init_scr_org"
    }
}

handler_openrc() {
    # shellcheck disable=SC2154 # SPD_SVC_AUTOSSH_RUNLVL defined in openrc_dependency_check()
    svc_runlevel_set "$(basename "$svc_script")" "$SPD_SVC_RUNBG_RUNLVL"
}

handler_sysv() {
    ln -sf "$svc_script" /etc/rc0.d/K01runbg
    ln -sf "$svc_script" /etc/rc1.d/K01runbg
    ln -sf "$svc_script" /etc/rc6.d/K01runbg

    ln -sf "$svc_script" /etc/rc2.d/S01runbg
    ln -sf "$svc_script" /etc/rc3.d/S01runbg
    ln -sf "$svc_script" /etc/rc4.d/S01runbg
    ln -sf "$svc_script" /etc/rc5.d/S01runbg
}

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"
    dependency_issue=0
    svc_script=/etc/init.d/runbg

    check_for_abort 1 task_prepare

    ensure_spd_var_defined SPD_SERVICE_HANDLER
    [ -n "$SPD_SERVICE_HANDLER" ] && {
        check_service_env
        [ "$SPD_SERVICE_HANDLER" = openrc ] && openrc_dependency_check
    }
    return "$dependency_issue"
}

task_execute() {
    check_for_abort 0 task_execute

    deploy_initd_script

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

[ -n "$DEPLOY_PATH" ] || {
    #  Run this in stand-alone mode
    DEPLOY_PATH=$(cd -- "$(dirname -- "$0")/.." && pwd)
    # shellcheck source=/dev/null
    . "$DEPLOY_PATH"/tools/prepare_env.sh
}
module_name="service_runbg.sh"
source_it "$DEPLOY_PATH"/tools/svc_handler_common.sh
source_it "$DEPLOY_PATH"/tools/svc_handler_openrc.sh

task_prepare && task_execute
