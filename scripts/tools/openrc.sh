#!/bin/sh
# shellcheck disable=SC2154
#
#  Copyright (c) 2021, 2022: Jacob.Lundqvist@gmail.com
#  License: MIT
#
#  Part of https://github.com/jaclu/spd
#
#  Handles openrc

#
# This should only be sourced...
#
_this_script="openrc.sh"
if [ "$(basename "$0")" = ${_this_script} ]; then
    echo "ERROR: ${_this_script} is not meant to be run stand-alone!"
    exit 1
fi
unset _this_script

# If you intend to work at a service in another run-level change this variable
rc_runlevel=default

#==========================================================
#
#   Public functions
#
#==========================================================

#
# Makes sure openrc is installed, and that default is the current run-level.
# ATM some fixes are done before checking current run-level:
#  1 deploy a patch to workaround the lacking /proc implementation in iSH
#  2 remove a service that complains about a broken dependency.
#    Since it isn't meaningful to run on an iOS device anyhow,
#    the simple solution is to just remove the file for now.
#
ensure_runlevel_default() {
    is_debian && return

    verbose_msg "ensure_runlevel_default()"

    if [ "$(rc-status -r)" != "default" ]; then
        rc_runlevel=default
        msg_2 "Setting runlevel $rc_runlevel"
        openrc $rc_runlevel
    fi
}

#
# Adds service mentioned in parameter 1 to $rc_runlevel
# File is assumed to have already been copied into /etc/init.d
#
# if parameter 2 is restart will restart the service once it it added
#
ensure_service_is_added() {
    srvc=$1
    runlevel=$2
    restart=$3

    verbose_msg "ensure_service_is_added(srvc=$srvc, runlevel=$runlevel, restart=$restart)"

    [ "$srvc" = "" ] && error_msg "ensure_service_is_added() called with param srvc"
    [ "$runlevel" = "" ] && error_msg "ensure_service_is_added() called with param runlevel"
    if [ "$(rc-status -u | grep "$srvc")" != "" ]; then
        echo "assigning [$srvc] to runlvl: [$runlevel]"
        # activate service
        rc-update add "$srvc" "$runlevel"
    fi
    if [ "$restart" = "restart" ]; then
        msg_3 "Restarting service"
        echo "To ensure current config will be used"
        rc-service "$srvc" restart
    fi

    unset srvc
    unset runlevel
    unset restart
}

#
# Removes service mentioned in parameter 1 from $rc_runlevel
#
disable_service() {
    srvc=$1
    runlevel=$2

    verbose_msg "disable_service(srvc=$srvc, runlevel=$runlevel)"
    [ "$srvc" = "" ] && error_msg "disable_service() called without param"
    [ "$runlevel" = "" ] && error_msg "disable_service() called without param run-level"
    if [ "$(rc-service -l | grep "$srvc")" != "" ]; then
        rc-service "$srvc" stop
        rc-update del "$srvc" "$rc_runlevel"
        _orc_disable_unset
        return 0
    else
        verbose_msg "service not found, so nothing to remove"
        _orc_disable_unset
        return 1
    fi
}

#==========================================================
#
#   Internals
#
#==========================================================

_orc_disable_unset() {
    # This is called from multiple point, make all the unsets in one place
    unset srvc
    unset runlevel
}

_orc_patch_one() {
    is_debian && return

    opo_fname="$1"
    opo_src="$DEPLOY_PATH/files/init.d/$opo_fname"
    if [ ! -e "$opo_src" ]; then
        echo
        echo "ERROR:openrc.sh:_orc_patch_one($opo_src) - no such file!"
        exit 1
    fi

    #
    #  This does not make sense, if I don't delete the file before networking
    #  ends up not being a copy, only work-arround I have found is to first
    #  delete the dest file.
    #
    rm "/etc/init.d/$opo_fname"

    cp "$opo_src" /etc/init.d

    md1="$(md5sum "$opo_src" | cut -d' ' -f 1)"
    md2="$(md5sum /etc/init.d/"$opo_fname" | cut -d' ' -f 1)"

    if [ ! "$md1" = "$md2" ]; then
        echo
        echo "ERROR:openrc.sh:_orc_patch_one($opo_src) - md5sum do not match!"
        echo "orig: [$md1]" # - $(ls -l $opo_src)"
        echo "copy: [$md2]" # - $(ls -l /etc/init.d/$opo_fname)"

        exit 1
    fi

    unset opo_fname
    unset opo_src
}

_NOT_problematic_service_hwdrivers() {
    if [ "$SPD_ISH_KERNEL" = "AOK" ]; then
        # AOK fs version of this service no longer displays warnings
        return
    fi

    bad_srvc=/etc/init.d/hwdrivers

    if test -f "$bad_srvc"; then
        #
        # TODO: check if this is no longer needed in order to avoid getting
        # warnings about hwdrivers not finding dependency 'dev'
        # Still needed: 2021-04-27
        #
        echo
        echo "============================================================"
        echo "Removing a failing service: $bad_srvc"
        echo "To avoid pointless warnings about non existent dependency."
        echo "Reinstalling openrc package should recreate this file"
        echo "============================================================"
        echo
        rm "$bad_srvc"
    fi
}

#
# This hack prevents all iSH service start and stops shoving an error
# about not finding /proc/filesystems iSH does not currently support
# that part of /proc
# This snippet does not require bash /bin/sh is enough.
# Needs to be run as root, but since this script already has that
# requirement it should be fine.
#
_NOT_patch_rc_cgroup_sh() {
    fname=/lib/rc/sh/rc-cgroup.sh
    fn_backup=${fname}.org

    ensure_installed coreutils

    func_name_line_no=$(grep -n "cgroup2_find_path()" $fname | cut --delimiter=":" --fields=1)
    insert_on_line=$((func_name_line_no + 2))

    # In order to expand tab below, through trial and error, I discovered
    # double expanding it turned out to work. Do not ask me why...
    patch_line="\\treturn 0  # ** Hack for iSH by jaclu ***"

    msg_3 "Examining if $fname needs patching"

    if [ "$SPD_ISH_KERNEL" = "AOK" ]; then
        echo "This patch is not needed on recent AOK systems"
        return
    fi

    # check content of line
    early_return=$(sed "$insert_on_line !d" $fname)

    #
    # Since bash most likely isn't available when this is first run,
    # we have to make do with /bin/sh and do string match
    #  using a case statement - argh...
    #
    case $early_return in

    *"return 0"*)
        msg_3 "Patch already applied"
        ;;

    *)
        msg_3 "Patch being applied"
        if [ -f "$fn_backup" ]; then
            echo "Found: $fn_backup"
            echo "Seems like patch was already applied"
            echo "First try:  mv $fn_backup $fname"
            echo "And then run this again, after that double check $fname"
            echo "To make sure cgroup2_find_path() returns 0"
            error_msg "Found $fn_backup read the above for further suggestions"
        fi
        echo "Making cgroup2_find_path() always return 0"
        echo "Saving original file to $fn_backup"
        cp $fname $fn_backup

        # kind of RPN, end result is an empty line after the patch line.
        # and the patch ends up on the expected line so will be detected
        # on later runs of this
        sed -i "$insert_on_line i \ " $fname
        sed -i "$insert_on_line i \ $patch_line" $fname

        msg_3 "Patch completed!"
        ;;

    esac
}
