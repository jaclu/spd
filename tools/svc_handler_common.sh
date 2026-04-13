#!/bin/sh

handle_initd_script() {
    [ -z "$service_name" ] && {
        err_msg "handle_initd_script() - service_name not defined"
    }
    [ -z "$init_scr_org" ] && {
        err_msg "handle_initd_script() - init_scr_org not defined"
    }
    service_script="/etc/init.d/$service_name"

    # shellcheck disable=SC2154 # opt_task defined by caller
    case "$opt_task" in
        install)
            cp "$init_scr_org" "$service_script" || {
                m="handle_initd_script() - Failed to copy"
                m="$m $init_scr_org $service_script"
                err_msg "$m"
            }
            lbl_3 "Copied $service_script"
            ;;
        remove) safe_remove --ignore-sys-path "$service_script" ;;
        *) err_msg "handle_initd_script() - invalid opt_task: [$opt_task]" ;;
    esac
}

check_service_env() {
    [ -z "$service_name" ] && {
        err_msg "check_service_env() - service_name not defined"
    }

    ensure_spd_var_defined SPD_SERVICE_HANDLER
    if [ -n "$SPD_SERVICE_HANDLER" ]; then
        # shellcheck disable=SC2154 # D_REPO & SPD_SERVICE_HANDLER defined by caller
        init_scr_org="$D_REPO/files/services/$SPD_SERVICE_HANDLER/$service_name"
        [ -f "$init_scr_org" ] || {
            lbl_2 "check_service_env() - Service script not found: [$init_scr_org]"
            dependency_issue=1
        }
        case "$SPD_SERVICE_HANDLER" in
            'openrc')
                lbl_3 "Using service handler: openrc"
                source_it "$D_REPO"/tools/svc_handler_openrc.sh
                openrc_dependency_check
                ;;
            'sysv-init')
                lbl_3 "Using service handler: sysv-init"
                source_it "$D_REPO"/tools/svc_handler_sysv_init.sh
                sysv_dependency_check
                ;;
            *)
                m="check_service_env() - Unrecognized service-handler"
                m="$m SPD_SERVICE_HANDLER: $SPD_SERVICE_HANDLER"
                err_msg "$m"
                ;;
        esac
    else
        lbl_2 "check_service_env() - SPD_SERVICE_HANDLER undefined"
        dependency_issue=1
    fi

    [ -d /etc/init.d ] || {
        lbl_2 "check_service_env() - Dependency issue - /etc/init.d not found"
        # shellcheck disable=SC2034 # dependency_issue used by caller
        dependency_issue=1
    }
}

process_service() {
    _ps_runlvl="$1"
    [ -z "$_ps_runlvl" ] && err_msg "process_service() called with no param"
    handle_initd_script

    # attach service to handler
    case "$SPD_SERVICE_HANDLER" in
        'openrc') handler_openrc "$_ps_runlvl" ;;
        'sysv-init') handler_sysv_init "$_ps_runlvl" ;;
        *)
            m="process_service() - Unrecognized service-handler"
            m="$m SPD_SERVICE_HANDLER: $SPD_SERVICE_HANDLER"
            err_msg "$m"
            ;;
    esac
}

#=====================================================================
#
#   Main
#
#=====================================================================

[ -z "$D_REPO" ] && {
    echo "svc_handler_common.sh - D_REPO undefined, this should be sourced"
}

[ -z "$service_name" ] && {
    err_msg "svc_handler_common.sh: service_name must be defined before sourcing this"
}
