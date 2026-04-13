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

    # shellcheck disable=SC2154 # opt_task defined by caller
    case "$opt_task" in
        install)
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
            lbl_1 "Removing service from runlevels"
            safe_remove --ignore-sys-path /etc/rc?.d/*"${service_name}"
            msg_dbg "Removed links for $service_name from runlevels"
            ;;
        *) err_msg "handler_sysv() unrecognized option: [$opt_task]" ;;
    esac
}
