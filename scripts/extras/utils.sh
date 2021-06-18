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
# Since all functions end up int the same namespace,
# ensure that all your functions and global variables
# are unique for this module, adding a short prefix based on script name,
# to ensure no other module will have colliding function names.
#
# Global variables should also be given thought, since if multiple modules
# are being loaded, then a task is called, a generically labeled global
# migh have been changed by another module.
#
# Variables set inside a function can use shortish names since
# you assigned it during processing.
# Try to be a good citizen and unset them as much as possible
# at exit of a function, since ash does not hanlde local variables :(
#
# The only exceptions are the following two functions that are only
# called in stand alone mode, their names will not collide, and are
# expected to allways be the same.
#
# _run_this()
#    Process this task(-s), called when param -h is not present
#
# _display_help()
#    Displays help for this task, called when param -h is present
#
# In testing you can either give -c then the config files will be read
# and all defined variables will be assigned before this is called.
# Be aware that if -c is given, all variables in the configs will
# get assigned, and most likely override variables set before running
# the module.
#
# You can set the variables you want to assign on the command line,
# something like:
#
# SPD_APKS_DEL='fortune' SPD_AKS_ADD='emacs-nox' ./m_tasks_apk.sh
#
# Finally a "main" block, as its last entry should allways look like this:
#
# To make them easier to find I recomend to define _display_help() and
# _run_this() at the end of your module. After those two you also need
# this main block, that triggers command line parsing, and stand alone
# run mode.
#
# if [ -z "$SPD_INITIAL_SCRIPT" ]; then
#
#     . "$DEPLOY_PATH/scripts/extras/utils.sh"
#
#     #
#     # Since sourced mode cant be detected in a practical way under ash,
#     # I use this workaround, first script is expected to set it, if set
#     # all other modules can assume to be sourced
#     #
#     SPD_INITIAL_SCRIPT=1
# fi
#



#
# This should only be sourced...
#
[ "$(basename "$0")" = "utils.sh" ] && error_msg "utils.sh is not meant to be run stand-alone!"



#==========================================================
#
#     Messagging and Error display
#
#==========================================================

error_msg() {
    msg=$1
    err_code=${2:-1}

    [ -z "$msg" ] && error_msg "error_msg() with no param"

    case $err_code in
        ''|*[!0-9]*)
            printf "PARAM ERROR: error_msg() Non numeric err_code given "
            echo "[$err_code] changed into 1"
            err_code=1
            ;;
    esac

    printf "\nERROR: %s\n\n" "$msg"

    clear_work_dir # clear tmp extract dir
    exit $err_code
}


warning_msg() {
    msg=$1
    
    [ -z "$msg" ] && error_msg "warning_msg() with no param"
    printf "\nWARNING: %s\n\n" "$msg"

    unset msg
}


#
# Only displayed if run with param -v
#
verbose_msg() {
    msg=$1
    
    [ -z "$msg" ] && error_msg "verbose_msg() with no param"
    [ "$p_verbose" = "1" ] && printf "VERBOSE: %s\n" "$msg"
    unset msg
}


#
#  Progress messages
#
msg_1() {
    #
    #   Display message centered inside a box
    #
    msg=$1
    max_length=42

    #
    # if msg was odd chars long, add a space to ensure it can be correctly
    # be split in half. Since this only handles ints, the /2*2 will result
    # in an even number rounded down.
    #
    [ "${#msg}" -ne "$(( ${#msg}/2*2 ))" ] && msg=" $msg"

    if [ "${#msg}" -ge "$max_length" ]; then
        # if string is to long, dont use padding
        pad_str=""
    else
        pad_length=$(( (max_length - ${#msg})/2  ))
        # posix friendly way of generating x instances of a char
        pad_str=$( head -c $pad_length  < /dev/zero | tr '\0' ' ' )
    fi

    border_line="+$( head -c $max_length  < /dev/zero | tr '\0' '=' )+"

    #
    # TODO:  When generating the spacer padding as a variable,
    # it only translates to one space, but if used as an expression,
    # all spaces are generated
    #
    #spacer_line="|$( head -c $max_length  < /dev/zero | tr '\0' ' ' )|"
    
    echo "$border_line"
    echo "|$( head -c $max_length  < /dev/zero | tr '\0' ' ' )|"
    echo "|$pad_str$msg$pad_str|"
    echo "|$( head -c $max_length  < /dev/zero | tr '\0' ' ' )|"
    echo "$border_line"
    echo
    
    unset msg
    unset max_length
}


msg_2() {
    msg=$1
    echo "=== $msg ==="
    unset msg
}


msg_3() {
    msg=$1
    echo "--- $msg ---"
    unset msg
}



#==========================================================
#
#     General public functions
#
#==========================================================


expand_deploy_path() {
    #
    #  Path not starting with / are asumed to be relative to
    #  $DEPLOY_PATH
    #
    this_path="$1"
    char_1=$(echo "$this_path" | head -c1)

    if [ "$char_1" = "/" ]; then
        echo "$this_path"
    elif [ -n "$this_path" ]; then
        expanded_path="$DEPLOY_PATH/$this_path"
        echo "$expanded_path"
	>/dev/srderr verbose_msg "    expanded into: $expanded_path"
    fi
    
    unset this_path
    unset char_1
    unset expanded_path
}


#
# Installs listed apk if not already installed, 2nd optional param is
# a message that is displayed if this is installed, default is to use
# "Installing dependency xxx"
# returns
#     0 if package was already installed
#     1 if package was installed now
#
ensure_installed() {
    pkg=$1
    msg=$2
    ret_val=0
    test -z "$pkg" && error_msg "ensure_installed() called with no param!"
    test -z "$msg" && msg="Installing dependency $pkg"
    if [ -z "$(apk info -e "$pkg")" ]; then
        msg_3 "$msg"
        apk add "$pkg"
        ret_val=1
    fi
    
    unset pk
    unset msg
    if [ $ret_val -eq 1 ]; then
        unset ret_val
	return 1
    fi
    unset ret_val
    return 0
}



#
# If in display mode, mentions if shell is missing,
# in work mode, this fails if SPD_SHELL is not pressent.
#
ensure_shell_is_installed() {
    SHELL_NAME=$1
     
     #  Splitting long params on separate lines

msg_3 "$(echo "Will be created as $SPD_UNAME:x:$SPD_UID"
         echo ":$SPD_GID::/home/$SPD_UNAME:$SPD_SHELL"
        )"

    [ -z "$SHELL_NAME" ] && error_msg "ensure_shell_is_installed() - no shell paraam!"
    if [ "$SPD_TASK_DISPLAY" = "1" ]; then
        test -x "$SHELL_NAME" || warning_msg "$SHELL_NAME not found\n>>>< Make sure it gets installed! ><<\n"
    else
        test -f "$SHELL_NAME" || error_msg "Shell not found: $SHELL_NAME"
        test -x "$SHELL_NAME" || error_msg "Shell not executable: $SHELL_NAME"
    fi
}



#
#  Handles a temp dir, for untaring stuff etc
#  calling it without param, just removes tmp dir
#  and all its content. Param 1 requests a new
#  tmp dir to be created
#
clear_work_dir() {
    new_space=$1

    extract_location="/tmp/restore-ish-$$"
    rm $extract_location -rf 2> /dev/null
    case "$new_space" in
    
        "1")
            mkdir -p $extract_location
            cd $extract_location || error_msg "clear_work_dir() could not cd !"
            ;;
            
        "")
            ;;
            
        *)
            echo
            echo "ERROR: clear_work_dir() accepted params: nothing|1"
            exit 1
            
    esac
    unset new_space
}



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
    save_current=$5
    old_home_dir="$home_dir-OLD"
    [ "$save_current" != "1" ] && save_current=0

    # (mostly) unverified params
    #verbose_msg "unpack_home_dir(username=$username, home=$home_dir, fname_tgz=$fname_tgz, unpacked_ptr=$unpacked_ptr, save_current=$save_current)"
    # TODO: verify that this split param aproach displays as intended!
    verbose_msg "$(
        printf "unpack_home_dir(username=%s, home=" "$username"
        printf "%s, fname_tgz=%s, , unpacked_ptr=" "$home_dir" "$fname_tgz"
        echo "$unpacked_ptr, save_current=$save_current)")"

    #
    #  Param checks
    #
    # Some of the checks below are ignored when $SPD_TASK_DISPLAY is 1 ie just inforoming what will happen
    [ -z "$username" ] && error_msg "unpack_home_dir() no username given"
    if [ ! "$SPD_TASK_DISPLAY" = "1" ] && [ "$(grep -c ^"$username" /etc/passwd)" != "1" ]; then
        error_msg "unpack_home_dir($username) - username not found in /etc/passwd"
    fi
    [ -z "$home_dir" ] && error_msg "unpack_home_dir() no home_dir given"
    if [ ! "$SPD_TASK_DISPLAY" = "1" ] && [ ! -d "$home_dir" ]; then
        error_msg "unpack_home_dir($username, $home_dir) - home_dir does not exist"
    fi
    if [ ! "$SPD_TASK_DISPLAY" = "1" ] && [ -z "$(find "$home_dir" -maxdepth 0 -user "$username")" ]; then
        error_msg "unpack_home_dir($username, $home_dir) - username does not own home_dir"
    fi
    if [ -z "$fname_tgz" ] || [ "$fname_tgz" = "1" ]; then
        error_msg "unpack_home_dir($username, $home_dir,) - No tar file to be extracted given"
    fi
    ! test -f "$fname_tgz" && error_msg "tar file not found:\n[$fname_tgz]"

    case "$unpacked_ptr" in
    
        "0"|"1" )
            # Not actual error, no unpacked_ptr given so save_current got shifted here"
            unpacked_ptr=""
            ;;

        *)
        
    esac
    
    #
    #  Actual work starts
    #
    msg_2 "$msg_txt"  # TODO: make $msg_txt a param!
    if [ "$save_current" = "1" ]; then
        do_unpack=1 # always restore
    else
        if test -f "$unpacked_ptr" && [ -n "$unpacked_ptr" ] ; then
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
            [ "$save_current" = "1" ] && msg_3 "Previous content will be moved to ${old_home_dir}"
        else
            clear_work_dir 1
            msg_3 "Extracting"
            echo "$fname_tgz"
            ! tar xfz "$fname_tgz" 2> /dev/null && error_msg "Failed to unpack tarball"
            if [ ! -d "$extract_location/$username" ]; then
                error_msg "No $username top dir found in the tarfile!"
            elif [ "$(find . -maxdepth 1 | wc -l)" != "2" ]; then
                # suspicious
                error_msg "Content outside intended destination found, check the tarfile!"
            fi
            echo "Successfully extracted content"
            
            if [ "$save_current" = "1" ]; then
                rm "$old_home_dir" -rf
                mv "$home_dir" "$old_home_dir"
                msg_3 "Previous content has been moved to ${old_home_dir}"
                mv "$username" "$home_dir"
            else
                msg_3 "Overwriting into current $home_dir"
                cd "$home_dir" || error_msg "Failed to cd into $home_dir"
                cd ..
                cp -a "$extract_location/$username" .
            fi
            msg_3 "$home_dir restored"
            clear_work_dir  # Remove tmp directory
        fi
    fi
}


parse_command_line() {
    #
    # Only process cmd line for initial_script
    #
    p_cfg=0
    p_help=0
    p_verbose=0
    while [ -n "$1" ]; do
        case "$1" in
            "-?" | "-h" | "--help")
                p_help=1
                ;;
		
	    "-v" | "--verbose")
	    	p_verbose=1
		;;
                
            "-c")
	        p_cfg=1
                ;;
                
	    *)
	        echo "WARNING: Unsupported param!: [$1]"
         esac
         shift
    done
    
    if [ $p_cfg -eq 1 ]; then
    	. "$DEPLOY_PATH/scripts/extras/read_config.sh"
    	read_config
    fi

    #
    # This is checked after all config files are processed, so if you really want to, you can
    # override this in a later config file....
    # If help is requested we will continue despite SPD_ABORT=1
    # Since nothing will be changed, and it helps testting scipts on non supported platforms. 
    #
    if [ "$SPD_TASK_DISPLAY" = "0" ] && [ $p_help = 0 ]; then
	[ "$SPD_ABORT" = "1" ] && error_msg "SPD_ABORT=1 detected. Will not run on this system."
    fi    
}


#==========================================================
#
#     Main
#
#==========================================================


#
#  Identify fiilesystem, some operations depend on it
#
test -d /AOK && SPD_FILE_SYSTEM='AOK' || SPD_FILE_SYSTEM='iSH' 


#
# 
#

if [ -z "$SPD_INITIAL_SCRIPT" ]; then
    parse_command_line "$@"

    if [ $p_help = 0 ]; then
       [ "$SPD_ABORT" = "1" ] && \
            error_msg "Detected SPD_ABORT=1  Your platform is most likely not supported!"
       [ "$(uname)" != "Linux" ] && error_msg "This only runs on Linux!"
	   [ "$(whoami)" != "root" ] && error_msg "Need to be root to run this"
        _run_this
    else
        _display_help
    fi
fi
