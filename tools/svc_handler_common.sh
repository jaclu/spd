#!/bin/sh

check_service_env() {
    _cse_svc="$1"
    [ -z "$_cse_svc" ] && {
        # shellcheck disable=SC2154 # module_name defined by caller
        err_msg "$module_name: check_service_env() called with empty service name"
    }

    if [ -n "$SPD_SERVICE_HANDLER" ]; then
        # shellcheck disable=SC2154 # D_REPO defined by $0
        _svc_init_scr_org="$D_REPO/files/services/$SPD_SERVICE_HANDLER/$_cse_svc"
        [ -f "$_svc_init_scr_org" ] || {
            lbl_2 "${module_name:-}: Service script not found: $_svc_init_scr_org"
            dependency_issue=1
        }
    else
        lbl_2 "$module_name: SPD_SERVICE_HANDLER undefined"
        dependency_issue=1
    fi

    [ -d /etc/init.d ] || {
        lbl_2 "$module_name: Dependency issue - /etc/init.d not found"
        # shellcheck disable=SC2034 # dependency_issue used by caller
        dependency_issue=1
    }
}
