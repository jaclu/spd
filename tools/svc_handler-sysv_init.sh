#!/bin/sh

sysv_dependency_check() {
    ensure_spd_var_defined SPD_SVC_SYSV_LVL_START
    ensure_spd_var_defined SPD_SVC_SYSV_LVL_STOP
    ensure_spd_var_defined SPD_SVC_SYSV_LVL_RUN_TASK
    ensure_spd_var_defined SPD_SVC_SYSV_LVL_KILL_TASK

    [ -d /etc/rc2.d ] || {
        lbl_2 "Dependency issue - /etc/rc2.d/ not found"
        # shellcheck disable=SC2034 # dependency_issue used by caller
        dependency_issue=1
    }
}

handler_sysv_init() {
    # Expecting the following variables to be defined in config:
    # SPD_SVC_SYSV_LVL_START - runlevels to start service on, e.g. "2 3 4 5"
    # SPD_SVC_SYSV_LVL_STOP - runlevels to stop service on, e.g. "0 1 6"
    # SPD_SVC_SYSV_LVL_RUN_TASK - number to prefix service script with in runlevels for starting, e.g. "20"
    # SPD_SVC_SYSV_LVL_KILL_TASK - number to prefix service script with in runlevels for stopping, e.g. "80"

    # shellcheck disable=SC2154 # opt_task defined by caller
    case "$opt_task" in
        install)
            lbl_3 "Adding service to runlevels"
            for lvl in $SPD_SVC_SYSV_LVL_STOP; do
                _f="/etc/rc${lvl}.d/K${SPD_SVC_SYSV_LVL_KILL_TASK}${service_name}"
                msg_dbg "linking $service_script to $_f" 1
                ln -sf "$service_script" "$_f"
            done
            for lvl in $SPD_SVC_SYSV_LVL_START; do
                _f="/etc/rc${lvl}.d/S${SPD_SVC_SYSV_LVL_RUN_TASK}${service_name}"
                msg_dbg "linking $service_script to $_f" 1
                ln -sf "$service_script" "$_f"
            done
            ;;
        remove)
            lbl_3 "Removing service from runlevels"
            # Since we can't be sure of previous S/K numbers, remove all links for the service from runlevels
            safe_remove --silent --ignore-sys-path /etc/rc?.d/*"${service_name}"
            msg_dbg "Removed links for $service_name from runlevels" 1
            ;;
        *) err_msg "handler_sysv() unrecognized option: [$opt_task]" ;;
    esac
}

# shellcheck disable=SC2034 # indicates this has been sourced, used by caller
SPD_SOURCED_SVC_HANDLER_SYSV_INIT=1
