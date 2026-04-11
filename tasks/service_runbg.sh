#!/bin/sh

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"

    read_config_file "$DEPLOY_PATH"/configs/service/runbg.yml
}

handler_openrc() {
}

handler_sysv() {
}

task_execute() {
    check_for_abort

    expand_config_var SPD_SVC_RUNBG_RUNLVL
    expand_config_var SPD_SERVICE_HANDLER

    [ -z "$SPD_SVC_RUNBG_RUNLVL" ] && err_msg "service_runbg.sh: Not defined - SPD_SVC_RUNBG_RUNLVL"
    [ -z "$SPD_SERVICE_HANDLER" ] && err_msg "service_runbg.sh: Not defined - SPD_SERVICE_HANDLER"
    
    _svc_file="$DEPLOY_PATH/files/service/$SPD_SERVICE_HANDLER/runbg"
    [ -f "$_svc_file" ] || err_msg "Service file not found: _svc_file"
    cp "$_svc_file" /etc/init.d || err_msg "Failed to copy $_svc_file"

    # perform the actual task
    case "$SPD_SERVICE_HANDLER" in
        'openrc') handler_openrc ;;
        'sysv-init') hansler_sysv ;;
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
