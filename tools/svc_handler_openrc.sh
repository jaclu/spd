#!/bin/sh

openrc_dependency_check() {
    ensure_spd_var_defined SPD_SVC_AUTOSSH_RUNLVL
    command -v openrc >/dev/null 2>&1 || {
        lbl_2 "Dependency issue - openrc not found"
        # shellcheck disable=SC2034 # dependency_issue used by caller
        dependency_issue=1
    }

}

handler_openrc() {
    _srs_srvc_runlevel="$1"
    [ -z "$_srs_srvc_runlevel" ] && err_msg "handler_openrc() - no param"

    # remove from all runlevels
    # shellcheck disable=SC2154 # service_name defined by caller
    rm -f /etc/runlevels/*/"$service_name" || echo "rm issue"

    # shellcheck disable=SC2154 # opt_task defined by caller
    if [ "$opt_task" = install ]; then
        lbl_3 "svc_runlevel_set() - will add $service_name to runlevel: $_srs_srvc_runlevel"
        rc-update add "$service_name" "$_srs_srvc_runlevel" || {
            m="svc_handler_openrc.sh: Failed cmd -"
            m="$m rc-update add $service_name $_srs_srvc_runlevel"
            err_msg "$m"
        }
    else
        lbl_3 "No longer started as service: $service_name"
    fi
}
