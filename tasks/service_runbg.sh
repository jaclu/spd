#!/bin/sh

deploy_initd_script() {
    cp "$_svc_init_scr_src" "$svc_script" || {
        err_msg "$module_name: Failed to copy $_svc_init_scr_src"
    }
}

handler_openrc() {
    source_it "$DEPLOY_PATH"/tools/svc_handler_openrc.sh
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

    check_for_abort 1 task_prepare

    dependency_issue=0
    svc_script=/etc/init.d/runbg

    expand_config_var SPD_SERVICE_HANDLER
    if [ -n "$SPD_SERVICE_HANDLER" ]; then
        echo "SPD_SERVICE_HANDLER: $SPD_SERVICE_HANDLER"
        [ "$SPD_SERVICE_HANDLER" = openrc ] && {
            command -v openrc >/dev/null 2>&1 || {
                lbl_2 "$module_name: Dependency issue - openrc not found"
                dependency_issue=1
            }
        }

        _svc_init_scr_src="$DEPLOY_PATH/files/services/$SPD_SERVICE_HANDLER/runbg"
        [ -f "$_svc_init_scr_src" ] || {
            lbl_2 "$module_name: Service script not found: $_svc_init_scr_src"
            dependency_issue=1
        }
    else
        lbl_2 "$module_name: Dependency issue - SPD_SERVICE_HANDLER not defined"
        dependency_issue=1
    fi

    expand_config_var SPD_SVC_RUNBG_RUNLVL
    [ "$SPD_SERVICE_HANDLER" = "openrc" ] && {
        if [ -n "$SPD_SVC_RUNBG_RUNLVL" ]; then
            echo "SPD_SVC_RUNBG_RUNLVL: $SPD_SVC_RUNBG_RUNLVL"
        else
            lbl_2 "$module_name: Dependency issue - SPD_SVC_RUNBG_RUNLVL not defined"
            dependency_issue=1
        fi
    }

    [ -d /etc/init.d ] || {
        lbl_2 "$module_name: Dependency issue - /etc/init.d not found"
        dependency_issue=1
    }
    return "$dependency_issue"
}

task_execute() {
    check_for_abort 0 task_execute

    # deploy_initd_script
    # [ -f "$svc_script" ] || err_msg "Service script not found: $svc_script"

    # # perform the actual task
    # case "$SPD_SERVICE_HANDLER" in
    #     'openrc') handler_openrc ;;
    #     'sysv-init') handler_sysv ;;
    #     *) err_msg "$module_name: Unrecognized service-handler: $SPD_SERVICE_HANDLER" ;;
    # esac
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

task_prepare || return 1
task_execute
