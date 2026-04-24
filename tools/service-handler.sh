#!/bin/sh

#---------------------------------------------------------------------
#
#   Service handler openrc
#
#---------------------------------------------------------------------

sh_openrc_dependency_check() {
    ensure_spd_var_defined SPD_SVC_OPENRC_RUNLVLS

    command -v openrc >/dev/null 2>&1 || {
        if fs_is_alpine; then
            lbl_2 "NOTICE: openrc missing - attempting to install"
            cmd_filtered_t sh -c 'apk update && apk add openrc'
        elif fs_is_debian; then
            lbl_2 "NOTICE: openrc missing - attempting to install"
            cmd_filtered_t sh -c 'apt update && apt install openrc'
        else
            lbl_2 "Dependency issue - openrc not found"
            # shellcheck disable=SC2034 # spd_dependency_issue used by caller
            spd_dependency_issue=1
        fi
    }
}

sh_handler_openrc() {
    # First remove from all runlevels, since we don't know previously used
    # runlevels and openrc doesn't have a simple way to remove from all runlevels,
    # this is done this is done by removing from all runlevels on file level

    # shellcheck disable=SC2154 # service_name defined by caller
    rm -f /etc/runlevels/*/"$service_name" || echo "rm issue"

    # shellcheck disable=SC2154 # opt_task defined by caller
    case "$opt_task" in
        install | force | force-install) ;;
        remove)
            lbl_3 "No longer used as service: $service_name"
            sh_handle_initd_script
            return
            ;;
        *) err_msg "sh_handler_openrc() unrecognized option: [$opt_task]" ;;
    esac

    # assume install

    sh_handle_initd_script
    # shellcheck disable=SC2154 # defined by caller
    for lvl in $SPD_SVC_OPENRC_RUNLVLS; do
        rc-update add "$service_name" "$lvl" || {
            m="svc_handler-openrc.sh: Failed cmd -"
            m="$m rc-update add $service_name $lvl"
            err_msg "$m"
        }
    done
    if [ -f /run/openrc/softlevel ]; then
        if [ "$opt_task" = install ]; then
            [ -e "/etc/runlevels/$(rc-status -r)/$service_name" ] && {
                # should be running in this runlevl
                lbl_3 "Manually starting service, since it should run in this runlevel"
                /etc/init.d/"$service_name" start
            }
        else
            lbl_3 "Will not auto start service installed with force-install"
        fi
    else
        lbl_3 "System didn't boot with openrc, so can't attempt to start service"
    fi
}

#---------------------------------------------------------------------
#
#   Service handler SysV-init
#
#---------------------------------------------------------------------

sh_sysv_dependency_check() {
    ensure_spd_var_defined SPD_SVC_SYSV_LVL_START
    ensure_spd_var_defined SPD_SVC_SYSV_LVL_STOP
    ensure_spd_var_defined SPD_SVC_SYSV_LVL_RUN_TASK
    ensure_spd_var_defined SPD_SVC_SYSV_LVL_KILL_TASK

    [ -d /etc/rc2.d ] || {
        lbl_2 "Dependency issue - /etc/rc2.d/ not found"
        # shellcheck disable=SC2034 # spd_dependency_issue used by caller
        spd_dependency_issue=1
    }
}

sh_handler_sysv_init() {
    # Expecting the following variables to be defined in config:
    # SPD_SVC_SYSV_LVL_START - runlevels to start service on, e.g. "2 3 4 5"
    # SPD_SVC_SYSV_LVL_STOP - runlevels to stop service on, e.g. "0 1 6"
    # SPD_SVC_SYSV_LVL_RUN_TASK - number to prefix service script with in runlevels for starting, e.g. "20"
    # SPD_SVC_SYSV_LVL_KILL_TASK - number to prefix service script with in runlevels for stopping, e.g. "80"

    # shellcheck disable=SC2154 # opt_task defined by caller
    case "$opt_task" in
        install | force | force-install) ;;
        remove)
            lbl_3 "Removing service from runlevels"
            # Since we can't be sure of previous S/K numbers, remove all links for the service from runlevels
            safe_remove --silent --ignore-sys-path /etc/rc?.d/*"${service_name}"
            dbg_msg "Removed links for $service_name from runlevels" 2
            sh_handle_initd_script
            return
            ;;
        *) err_msg "sh_handler_sysv_init() unrecognized option: [$opt_task]" ;;
    esac

    # assume install

    sh_handle_initd_script
    lbl_3 "Adding service to runlevels"
    # shellcheck disable=SC2154 # defined by caller
    for lvl in $SPD_SVC_SYSV_LVL_STOP; do
        _hs_zero_prefix=$(printf '%02d\n' "$SPD_SVC_SYSV_LVL_KILL_TASK")
        _f="/etc/rc${lvl}.d/K${_hs_zero_prefix}${service_name}"
        dbg_msg "linking $service_script to $_f" 3
        ln -sf "$service_script" "$_f"
    done
    # shellcheck disable=SC2154 # defined by caller
    for lvl in $SPD_SVC_SYSV_LVL_START; do
        _hs_zero_prefix=$(printf '%02d\n' "$SPD_SVC_SYSV_LVL_RUN_TASK")
        _f="/etc/rc${lvl}.d/S${_hs_zero_prefix}${service_name}"
        dbg_msg "linking $service_script to $_f" 3
        ln -sf "$service_script" "$_f"
    done
}

#---------------------------------------------------------------------
#
#   common service handler tasks
#
#---------------------------------------------------------------------

sh_handle_initd_script() {
    [ -z "$service_name" ] && {
        err_msg "sh_handle_initd_script() - service_name not defined"
    }
    [ -z "$init_scr_org" ] && {
        err_msg "sh_handle_initd_script() - init_scr_org not defined"
    }
    service_script="/etc/init.d/$service_name"

    # shellcheck disable=SC2154 # opt_task defined by caller
    case "$opt_task" in
        install | force | force-install)
            cp "$init_scr_org" "$service_script" || {
                m="sh_handle_initd_script() - Failed to copy"
                m="$m $init_scr_org $service_script"
                err_msg "$m"
            }
            lbl_3 "Copied $service_script"
            ;;
        remove) safe_remove --ignore-sys-path "$service_script" ;;
        *) err_msg "sh_handle_initd_script() - invalid opt_task: [$opt_task]" ;;
    esac
}

#---------------------------------------------------------------------
#
#   Public methods
#
#---------------------------------------------------------------------

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
            spd_dependency_issue=1
        }
        case "$SPD_SERVICE_HANDLER" in
            openrc)
                lbl_3 "Using service handler: openrc"
                sh_openrc_dependency_check
                ;;
            sysv-init)
                lbl_3 "Using service handler: sysv-init"
                sh_sysv_dependency_check
                ;;
            *)
                m="check_service_env() - Unrecognized service-handler"
                m="$m SPD_SERVICE_HANDLER: $SPD_SERVICE_HANDLER"
                err_msg "$m"
                ;;
        esac
    else
        lbl_2 "check_service_env() - SPD_SERVICE_HANDLER undefined"
        spd_dependency_issue=1
    fi

    [ -d /etc/init.d ] || {
        lbl_2 "check_service_env() - Dependency issue - /etc/init.d not found"
        # shellcheck disable=SC2034 # spd_dependency_issue used by caller
        spd_dependency_issue=1
    }
}

process_service() {
    # attach service to handler
    case "$SPD_SERVICE_HANDLER" in
        'openrc') sh_handler_openrc ;;
        'sysv-init') sh_handler_sysv_init ;;
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
    echo "service-handler.sh - D_REPO undefined, this should be sourced"
}

[ -z "$service_name" ] && {
    err_msg "service-handler.sh: service_name must be defined before sourcing this"
}

# shellcheck disable=SC2034 # indicates this has been sourced, used by caller
SPD_SOURCED_SERVICE_HANDLER=1
