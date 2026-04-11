#!/bin/sh

deploy_initd_script() {
    [ -z "$SPD_SVC_RUNBG_RUNLVL" ] && err_msg "service_runbg.sh: Not defined - SPD_SVC_RUNBG_RUNLVL"
    [ -z "$SPD_SERVICE_HANDLER" ] && err_msg "service_runbg.sh: Not defined - SPD_SERVICE_HANDLER"

    svc_script=/etc/init.d/runbg

    _svc_Init_scr_src="$DEPLOY_PATH/files/service/$SPD_SERVICE_HANDLER/runbg"
    [ -f "$_svc_Init_scr_src" ] || err_msg "Service file not found: _svc_Init_scr_src"
    cp "$_svc_Init_scr_src" "$svc_script" || err_msg "Failed to copy $_svc_Init_scr_src"
}

handler_openrc() {
    source_it "$DEPLOY_PATH"/tools/svc_handler_openrc.sh
    svc_runlevel_set runbg "$SPD_SVC_RUNBG_RUNLVL"
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

    read_config_file "$DEPLOY_PATH"/configs/service/runbg.yml
}

task_execute() {
    check_for_abort

    expand_config_var SPD_SVC_RUNBG_RUNLVL
    expand_config_var SPD_SERVICE_HANDLER

    deploy_initd_script
    [ -f "$svc_script" ] || err_msg "Service script not found: $svc_script"

    # perform the actual task
    case "$SPD_SERVICE_HANDLER" in
        'openrc') handler_openrc ;;
        'sysv-init') handler_sysv ;;
        *) err_msg "service_runbg.sh: Unrecognized service-handler: $SPD_SERVICE_HANDLER" ;;
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

task_prepare
task_execute
