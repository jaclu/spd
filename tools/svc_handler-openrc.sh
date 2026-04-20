#!/bin/sh

openrc_dependency_check() {
    ensure_spd_var_defined SPD_SVC_OPENRC_RUNLVLS

    command -v openrc >/dev/null 2>&1 || {
        lbl_2 "Dependency issue - openrc not found"
        # shellcheck disable=SC2034 # dependency_issue used by caller
        dependency_issue=1
    }
}

handler_openrc() {
    # First remove from all runlevels, since we don't know previously used
    # runlevels and openrc doesn't have a simple way to remove from all runlevels,
    # this is done this is done by removing from all runlevels on file level

    # shellcheck disable=SC2154 # service_name defined by caller
    rm -f /etc/runlevels/*/"$service_name" || echo "rm issue"

    # shellcheck disable=SC2154 # opt_task defined by caller
    if [ "$opt_task" = install ]; then
        for lvl in $SPD_SVC_OPENRC_RUNLVLS; do
            rc-update add "$service_name" "$lvl" || {
                m="svc_handler-openrc.sh: Failed cmd -"
                m="$m rc-update add $service_name $lvl"
                err_msg "$m"
            }
        done
    else
        lbl_3 "No longer used as service: $service_name"
    fi
}

# shellcheck disable=SC2034 # indicates this has been sourced, used by caller
SPD_SOURCED_SVC_HANDLER_OPENRC=1
