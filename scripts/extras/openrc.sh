#!/bin/sh
#
# Copyright (c) 2021: Jacob.Lundqvist@gmail.com 2021-04-30
# License: MIT
#
# Version: 0.1.0 2021-04-30
#    Initial release
#
# Part of ishTools
#

#
# This should only be sourced...
#
[ "$(basename "$0")" = "openrc.sh" ] && error_msg "utils.sh is not meant to be run stand-alone!"


# If you intend to work at a service in another runlevel change this variable
rc_runlevel=default



#==========================================================
#
#   Public functions
#
#==========================================================

#
# Makes sure openrc is installed, and that default is the current runlevel.
# ATM some fixes are done before checking current runlevel:
#  1 deploy a patch to workaround the lacking /proc implementation in iSH
#  2 remove a service that complains about a broken dependency.
#    Since it isn't meaningful to run on an iOS device anyhow,
#    the simple solution is to just remove the file for now.
#
ensure_runlevel_default() {
    verbose_msg "ensure_runlevel_default()"
    
    ensure_installed openrc
       
    if [ "$(rc-status -r)" != "default" ]; then
        rc_runlevel=default
        msg_2 "Setting runlevel $rc_runlevel"
        openrc $rc_runlevel
    fi
}


#
# Adds service mentioned in param1 to $rc_runlevel
# File is assumed to have already been copied into /etc/init.d
#
# if param2 is restart will restart the service once it it added
#
ensure_service_is_added() {
    srvc=$1
    runlevel=$2
    restart=$3
    
    verbose_msg "ensure_service_is_added(srvc=$srvc, runlevel=$runlevel, restart=$restart)"

    [ "$srvc" = "" ] && error_msg "ensure_service_is_added() called without param srvc"
    [ "$runlevel" = "" ] && error_msg "ensure_service_is_added() called without param runlevel"
    if [ "$(rc-status -u | grep "$srvc")" != "" ]; then
        echo "assigning [$srvc] to runlvl: [$runlevel]"
        # activate service
        rc-update add "$srvc" "$runlevel"
    fi
    if [ "$restart" = "restart" ]; then
        msg_3 "Restarting service"
        echo "To ensure curent config will be used"
        rc-service "$srvc" restart
    fi

    unset srvc
    unset runlevel
    unset restart
}


#
# Removes service mentioned in param1 from $rc_runlevel
#
disable_service() {
    srvc=$1
    runlevel=$2
    
    verbose_msg "disable_service(srvc=$srvc, runlevel=$runlevel)"
    [ "$srvc" = "" ] && error_msg "disable_service() called without param"
    [ "$runlevel" = "" ] && error_msg "disable_service() called without param runlevel"
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


_NOT_problematic_service_hwdrivers() {
    if [ "$SPD_FILE_SYSTEM" = "AOK" ]; then
        # AOK fs version of this service no longer displays warnings
        return
    fi

    bad_srvc=/etc/init.d/hwdrivers
    
    if test -f "$bad_srvc" ; then
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
# about not finding /proc/filesystems iSH does not currently suppport
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
    insert_on_line=$((func_name_line_no+2))

    # In order to exand tab below, through trial and error, I discovered
    # double expanding it turned out to work. Do not ask me why...
    patch_line="\\treturn 0  # ** Hack for iSH by jaclu ***"

    msg_3 "Examining if $fname needs patching"

    if [ "$SPD_FILE_SYSTEM" = "AOK" ]; then
        echo "This patch is not needed on recent AOK file systems"
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
            msg_3 "Patch beeing applied"
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
