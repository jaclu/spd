#!/bin/sh

deploy_initd_script() {
    # shellcheck disable=SC2154 # _svc_init_scr_org defined in svc_handler_common.sh
    cp "$_svc_init_scr_org" "$svc_script" || {
        err_msg "$module_name - Failed to copy $_svc_init_scr_org"
    }

    # tweak _svc_init_scr_org, with SPD_SVC_AUTOSSH_ settings
    if is_macos; then
        sed_cmd="sed -i ''"
    else
        sed_cmd="sed -i"
    fi

    # shellcheck disable=SC2154 # SPD_ vars via config files
    {
        loopback_cmd="$SPD_SVC_AUTOSSH_REVERSE_PORT:localhost:$SPD_SSHD_PORT"
        $sed_cmd "s|^LOOPBACK_DIRECIVE.*|loopback_directive=\"$loopback_cmd\"|" \
            "$svc_script" || {

            err_msg "$module_name: Failed to replace LOOPBACK_DIRECIVE"
        }

        $sed_cmd "s|^KEY_FILE.*|key_file=\"$SPD_SVC_AUTOSSH_KEY_FILE\"|" \
            "$svc_script" || {

            err_msg "$module_name: Failed to replace KEY_FILE"
        }
        $sed_cmd "s|^JUMP_PORT.*|jump_port=\"$SPD_SVC_AUTOSSH_JUMP_PORT\"|" \
            "$svc_script" || {

            err_msg "$module_name: Failed to replace JUMP_PORT"
        }
        $sed_cmd \
            "s|^JUMP_ACCOUNT.*|jump_account=\"$SPD_UNAME@$SPD_SVC_AUTOSSH_JUMP_HOST\"|" \
            "$svc_script" || {

            err_msg "$module_name: Failed to replace JUMP_ACCOUNT"
        }
    }
}

handler_openrc() {
    # shellcheck disable=SC2154 # SPD_SVC_AUTOSSH_RUNLVL defined in openrc_dependency_check()
    svc_runlevel_set "$(basename "$svc_script")" "$SPD_SVC_AUTOSSH_RUNLVL"
}

handler_sysv() {
    ln -sf "$svc_script" /etc/rc0.d/K01autossh
    ln -sf "$svc_script" /etc/rc1.d/K01auossh
    ln -sf "$svc_script" /etc/rc6.d/K01auossh

    ln -sf "$svc_script" /etc/rc2.d/S05auossh
    ln -sf "$svc_script" /etc/rc3.d/S05auossh
    ln -sf "$svc_script" /etc/rc4.d/S05auossh
    ln -sf "$svc_script" /etc/rc5.d/S05auossh
}

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"
    dependency_issue=0
    svc_script=/etc/init.d/autossh

    check_for_abort 1 task_prepare

    ensure_spd_var_defined SPD_SERVICE_HANDLER
    if [ -n "$SPD_SERVICE_HANDLER" ]; then
        check_service_env
        [ "$SPD_SERVICE_HANDLER" = openrc ] && openrc_dependency_check
    fi

    ensure_spd_var_defined SPD_SVC_AUTOSSH_JUMP_HOST
    ensure_spd_var_defined SPD_SSHD_PORT
    ensure_spd_var_defined SPD_SVC_AUTOSSH_JUMP_PORT
    ensure_spd_var_defined SPD_SVC_AUTOSSH_REVERSE_PORT
    ensure_spd_var_defined SPD_SVC_AUTOSSH_KEY_FILE
    return "$dependency_issue"
}

task_execute() {
    check_for_abort 0 task_execute

    deploy_initd_script

    # perform the actual task
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
    # shellcheck source=tools/prepare_env.sh
    . "$DEPLOY_PATH"/tools/prepare_env.sh
}
module_name="service_auossh.sh"
source_it "$DEPLOY_PATH"/tools/svc_handler_common.sh
source_it "$DEPLOY_PATH"/tools/svc_handler_openrc.sh

task_prepare && task_execute
