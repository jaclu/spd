#!/bin/sh

svc_runlevel_set() {
    _srs_srvc_name="$1"
    _srs_srvc_runlevel="$2"

    # Remove from undesired runlevels
    for rl in $(rc-status -l); do
        [ "$rl" = "$_srs_srvc_runlevel" ] && continue
        if rc-status "$rl" | grep -qw "$_srs_srvc_name"; then
            rc-update del "$_srs_srvc_name" "$rl" || exit 30
            echo "removed from: $rl"
        fi
    done

    # Ensure in desired runlevel
    if ! rc-update show "$_srs_srvc_runlevel" | grep -q "$(basename "$_srs_srvc_name")"; then
        rc-update add "$_srs_srvc_name" "$_srs_srvc_runlevel" || {
            _m="svc_handler_openrc.sh: Failed to add $_srs_srvc_name"
            _m="$_m to runlevel $_srs_srvc_runlevel"
            err_msg "$_m"
        }
        echo "added to $_srs_srvc_runlevel"
    fi
}
