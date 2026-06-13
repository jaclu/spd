#!/bin/sh
# Fake shebang, this is always sourced. Intended to hint file-type for  linters/editors
#
# Part of https://github.com/jaclu/spd
#
# Copyright (c) 2026 Jacob Lundqvist <jacob.lndqvist@gmail.com>
# License: MIT
#

#---------------------------------------------------------------------
#
#   common service handler tasks
#
#---------------------------------------------------------------------

sh_init_d_script_install() {
    if [ -f "$f_spd_init_scr_org" ]; then
        lbl_3 "Will copy $f_spd_init_scr_org -> $f_spd_init_scr" 1
        cp -a "$f_spd_init_scr_org" "$f_spd_init_scr" || {
            m="sh_init_d_script_install() - Failed to copy"
            m="$m $f_spd_init_scr_org $f_spd_init_scr"
            err_msg "$m"
        }
        [ -f "$f_service_script" ] && {
            lbl_4 "Removing prior $f_service_script" 1
            rm -f "$f_service_script" || err_msg "Failed to rm $f_service_script"
        }
        lbl_3 "Linking spd service script into place" 1
        ln -sf "$f_spd_init_scr" "$f_service_script" || {
            err_msg "Failed to softlink $f_spd_init_scr $f_service_script"
        }
    elif [ -f "$f_sys_init_scr" ]; then
        lbl_3 "Linking system service script into place" 1
        ln -sf "$f_sys_init_scr" "$f_service_script" || {
            err_msg "Failed to softlink $f_sys_init_scr $f_service_script"
        }
    else
        err_msg "Unable to find service init script"
    fi
    lbl_3 "Service script deployed!" 1
}

sh_init_d_script_remove() {
    lbl_3 "Removing service script for: $service_name" 1
    safe_remove --ignore-sys-path "$f_service_script"
    [ -f "$f_spd_init_scr" ] && safe_remove --ignore-sys-path "$f_spd_init_scr"
}

sh_initd_script_handle() {
    [ -z "$service_name" ] && {
        err_msg "sh_initd_script_handle() - service_name not defined"
    }
    [ -z "$f_spd_init_scr_org" ] && {
        err_msg "sh_initd_script_handle() - f_spd_init_scr_org not defined"
    }

    # shellcheck disable=SC2154 # opt_task defined by caller
    case "$opt_task" in
        install | force | force-install) sh_init_d_script_install ;;
        remove) sh_init_d_script_remove ;;
        *) err_msg "sh_initd_script_handle() - invalid opt_task: [$opt_task]" ;;
    esac
}

#---------------------------------------------------------------------
#
#   Service handler openrc
#
#---------------------------------------------------------------------

sh_openrc_dependency_check() {
    ensure_spd_var_defined SPD_SVC_OPENRC_RUNLVLS # || return # no need to continue

    command -v openrc >/dev/null 2>&1 || {
        _sodc_pkg=openrc
        package_install "$_sodc_pkg" || {
            lbl_1 "Failed to install: $_sodc_pkg"
            spd_dependency_issue=1
        }
    }
}

sh_handler_openrc() {
    # First remove from all runlevels, since we don't know previously used
    # runlevels and openrc doesn't have a simple way to remove from all runlevels,
    # this is done this is done by removing from all runlevels on file level

    # shellcheck disable=SC2154 # service_name defined by caller
    rm -f /etc/runlevels/*/"$service_name" || err_msg "Failed: to remove $service_name from /etc/runlevels/"

    sh_initd_script_handle
    # shellcheck disable=SC2154 # opt_task defined by caller
    case "$opt_task" in
        install | force | force-install) ;;
        remove)
            lbl_3 "No longer used as service: $service_name" 1
            return
            ;;
        *) err_msg "sh_handler_openrc() unrecognized option: [$opt_task]" ;;
    esac

    # assume install

    if is_debug_lvl 1; then
        _sh_dev_output=/dev/stdout
    else
        _sh_dev_output=/dev/null
    fi
    # shellcheck disable=SC2154 # defined by caller
    for lvl in $SPD_SVC_OPENRC_RUNLVLS; do
        rc-update add "$service_name" "$lvl" >"$_sh_dev_output" || {
            m="svc_handler-openrc.sh: Failed cmd -"
            m="$m rc-update add $service_name $lvl"
            err_msg "$m"
        }
    done
    if [ -f /run/openrc/softlevel ]; then
        if [ "$opt_task" = install ]; then
            [ -e "/etc/runlevels/$(rc-status -r)/$service_name" ] && {
                # should be running in this runlevl
                lbl_3 "Manually starting service, since it should run in this runlevel" 1
                "$f_service_script" start
            }
        else
            lbl_3 "Will not auto start service installed with force-install" 1
        fi
    else
        lbl_3 "System didn't boot with openrc, so can't attempt to start service" 1
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

    # [ "$spd_dependency_issue" -ge 1 ] && return 1

    [ -d /etc/init.d ] || {
        lbl_1 "Dependency issue - /etc/init.d not found"
        spd_dependency_issue=1
    }

    # Verify that the expected destinations where to list the service at
    # various runlevels do exist
    for _ssdc_rl in 0 1 2 3 4 5 6; do
        _ssdc_d="/etc/rc${_ssdc_rl}.d"
        [ -d "$_ssdc_d" ] || {
            lbl_1 "Dependency issue - $_ssdc_d/ not found"
            # shellcheck disable=SC2034 # spd_dependency_issue used by caller
            spd_dependency_issue=1
        }
    done
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
            lbl_3 "Removing service from runlevels" 1
            # Since we can't be sure of previous S/K numbers, remove all links for the service from runlevels
            safe_remove --silent --ignore-sys-path /etc/rc?.d/*"${service_name}"
            dbg_msg "Removed links for $service_name from runlevels" 2
            sh_initd_script_handle
            return
            ;;
        *) err_msg "sh_handler_sysv_init() unrecognized option: [$opt_task]" ;;
    esac

    # assume install

    sh_initd_script_handle

    lbl_3 "Adding service to runlevels" 1
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
#   Public methods
#
#---------------------------------------------------------------------

check_service_env() {
    [ -z "$service_name" ] && {
        err_msg "check_service_env() - service_name not defined"
    }

    ensure_spd_var_defined SPD_SERVICE_HANDLER
    # shellcheck disable=SC2154 # SPD_SERVICE_HANDLER defined via config
    case "$SPD_SERVICE_HANDLER" in
        openrc)
            sh_openrc_dependency_check
            ;;
        sysv-init)
            sh_sysv_dependency_check
            ;;
        '') err_msg "check_service_env() - SPD_SERVICE_HANDLER undefined" ;;
        *)
            m="check_service_env() - Unrecognized service-handler"
            m="$m SPD_SERVICE_HANDLER: $SPD_SERVICE_HANDLER"
            err_msg "$m"
            ;;
    esac

    # [ -f "$f_spd_init_scr_org" ] || {
    #     lbl_1 "check_service_env() - Service script not found: [$f_spd_init_scr_org]"
    #     spd_dependency_issue=1
    # }
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

[ -n "$D_REPO" ] || {
    printf '\n%s[%s] ERROR: This can not be run directly, should be sourced.\n' "$0" "$$" >&2
    exit 1
}

[ -z "$service_name" ] && {
    err_msg "service-handler.sh: service_name must be defined before sourcing this"
}

f_service_script=/etc/init.d/"$service_name"

# shellcheck disable=SC2154 # variables defined in configs
{
    f_spd_init_scr_org="$D_REPO/files/services/$SPD_SERVICE_HANDLER/$service_name"
    f_sys_init_scr="$SPD_SVC_DISABLED_DIR/$service_name"
    f_spd_init_scr="$SPD_SVC_MANAGED_DIR/$service_name"
}

#
#  Hint to indicate this has been sourced
#
# shellcheck disable=SC2034 # indicates this has been sourced, used by caller
service_handler_is_sourced=1
