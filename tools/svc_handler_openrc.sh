#!/bin/sh

openrc_dependency_check() {
    ensure_spd_var_defined SPD_SVC_AUTOSSH_RUNLVL
    command -v openrc >/dev/null 2>&1 || {
        lbl_2 "${module_name:-}: Dependency issue - openrc not found"
        # shellcheck disable=SC2034 # dependency_issue used by caller
        dependency_issue=1
    }

}

svc_runlevel_set() {
    _srs_srvc_name="$1"
    _srs_srvc_runlevel="$2"

    lbl_1 "svc_runlevel_set() current_dbg_lvl [$current_dbg_lvl]"

    # # shellcheck disable=SC2154 # current_dbg_lvl defined by caller
    # if [ "$current_dbg_lvl" = 0 ]; then
    #     _srs_redirect=" > /dev/null 2>&1"
    # else
    #     _srs_redirect=""
    # fi

    lbl_3 "svc_runlevel_set() - will remove undesirable runlevels for: $_srs_srvc_name"

    # Remove from undesired runlevels
    for rl in $(rc-status -l); do
        msg_dbg "Checking runlevel: $rl"
        [ "$rl" = "$_srs_srvc_runlevel" ] || continue
        lbl_3 "rl is [$rl]"
        if rc-status "$rl" | grep -qw "$_srs_srvc_name"; then
            lbl_4 "Processing this runlevel"
            if [ "$current_dbg_lvl" = 0 ]; then
                lbl_4 "Removing $_srs_srvc_name from runlevel: $rl (quiet mode)"
                rc-update del "$_srs_srvc_name" "$rl" >/dev/null 2>&1
                ex_code="$?"
            else
                lbl_4 "Removing $_srs_srvc_name from runlevel: $rl (verbose mode)"
                rc-update del "$_srs_srvc_name" "$rl"
                ex_code="$?"
            fi
            [ "$ex_code" = 0 ] || {
                m="svc_handler_openrc.sh: Failed cmd -"
                m="$m rc-update del $_srs_srvc_name $rl"
                err_msg "$m"
            }
            echo "$_srs_srvc_name removed from runlevel: $rl"
        fi
    done

    lbl_3 "svc_runlevel_set() - will add to desirable runlevels for: $_srs_srvc_name"
    # Ensure in desired runlevel
    if ! rc-update show "$_srs_srvc_runlevel" \
        | grep -q "$(basename "$_srs_srvc_name")"; then

        if [ "$current_dbg_lvl" = 0 ]; then
            rc-update add "$_srs_srvc_name" "$_srs_srvc_runlevel" >/dev/null 2>&1
            ex_code="$?"
        else
            rc-update add "$_srs_srvc_name" "$_srs_srvc_runlevel"
            ex_code="$?"
        fi
        [ "$ex_code" = 0 ] || {
            m="svc_handler_openrc.sh: Failed cmd -"
            m="$m rc-update add $_srs_srvc_name $_srs_srvc_runlevel"
            err_msg "$m"
        }
        echo "$_srs_srvc_name added to runlevel: $_srs_srvc_runlevel"
    fi
    lbl_2 "  svc_runlevel_set() - done"
}
