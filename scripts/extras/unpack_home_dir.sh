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
[ "$(basename $0)" = "unpack_home_dir.sh" ] && error_msg "utils.sh is not meant to be run stand-alone!" 1


#
#  Restore $home_dir unless $unpacked_ptr points to an existing file.
#  If $save_current is 1, curent home dir is moved to $home_dir-OLD and
#  always restored.
#
unpack_home_dir() {
    username=$1
    home_dir=$2
    fname_tgz=$3
    unpacked_ptr=$4
    save_current=$5 ; [ "$save_current" != "1" ] && save_current=0

    # Below we will get errors if this is not set, so set it to a harmless default
    # In normal operations this is always already set, so this is just to handle
    # debugging or standalone task runs.
    if [ "$SPD_TASK_DISPLAY" = "" ]; then
        error_msg "unpack_home_dir() SPD_TASK_DISPLAY must be defined" 1
    fi

    # (mostly) unverified params
    #echo "unpack_home_dir($username,$home_dir,$fname_tgz,$unpacked_ptr,$save_current)"

    #
    #  Param checks
    #
    # Some of the checks below are ignored when $SPD_TASK_DISPLAY is 1 
    # ie just inforoming what will happen
    #
    [ "$username" = "" ] && error_msg "unpack_home_dir() no username given" 1
    [ ! "$SPD_TASK_DISPLAY" = "1" ] && [ "$(grep -c ^"$username" /etc/passwd)" != "1" ] && error_msg "unpack_home_dir($username) - username not found in /etc/passwd" 1
    [ "$home_dir" = "" ] && error_msg "unpack_home_dir() no home_dir given" 1
    [ ! "$SPD_TASK_DISPLAY" = "1" ] && [ ! -d "$home_dir" ] && error_msg "unpack_home_dir($username, $home_dir) - home_dir does not exist" 1
    [ ! "$SPD_TASK_DISPLAY" = "1" ] && [ "$(find "$home_dir" -maxdepth 0 -user "$username")" = "" ] && error_msg "unpack_home_dir($username, $home_dir) - username does not own home_dir" 1
    [ "$fname_tgz" = "" ] || [ "$fname_tgz" = "1" ] && error_msg "unpack_home_dir($username, $home_dir,) - No tar file to be extracted given" 1
    ! test -f "$fname_tgz" && error_msg "tar file not found:\n[$fname_tgz]" 1
    case "$unpacked_ptr" in
    
        "0"|"1" )
            # Not actual error, no unpacked_ptr given so save_current got shifted here"
            unpacked_ptr=""
            ;;

        *)
        
    esac
    
    # Parsed, verified and in some cases shifted params
    #echo "unpack_home_dir($username,$home_dir,$fname_tgz,$unpacked_ptr,$save_current) - verified params"
 
    #
    #  Actual work starts
    #
    msg_2 "$msg_txt"
    if [ "$save_current" = "1" ]; then
        do_unpack=1 # always restore
    else
        if test -f "$unpacked_ptr" && [ "$unpacked_ptr" != "" ] ; then
            msg_3 "Already restored"
            echo "Found: $unpacked_ptr"
            do_unpack=0
        else
            do_unpack=1
        fi
    fi
    if [ "$do_unpack" = "1" ]; then
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            msg_3 "Will be restored"
             echo "Using: $fname_tgz"
            if [ "$save_current" = "1" ]; then
                msg_3 "Previous content will be moved to ${home_dir}-OLD"
            fi
        else
            clear_work_dir 1
            msg_3 "Extracting"
            echo "$fname_tgz"
            if ! tar xfz "$fname_tgz" 2> /dev/null ; then
                error_msg "Failed to unpack tarball" 1
            fi
            if [ ! -d "$extract_location/$username" ]; then
                error_msg "No $username top dir found in the tarfile!" 1
            elif [ "$(find . -maxdepth 1 | wc -l)" != "2" ]; then
                # suspicious
                error_msg "Content outside intended destination found, check the tarfile!" 1
            fi
            echo "Successfully extracted content"

            if [ "$save_current" = "1" ]; then
                rm "$home_dir"-OLD -rf
                mv "$home_dir" "$home_dir}"-OLD
                msg_3 "Previous content has been moved to ${home_dir}-OLD"
                mv "$username" "$home_dir"
            else
                msg_3 "Overwriting into current $home_dir"
                cd "$home_dir" || error_msg "Failed to cd into $home_dir" 1
                cd ..
                cp -a "$extract_location/$username" .
            fi
            msg_3 "$home_dir restored"
            clear_work_dir  # Remove tmp directory
        fi
    fi
}
