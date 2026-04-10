#!/bin/sh
# shellcheck disable=SC2154
#
# Copyright (c) 2021: Jacob.Lundqvist@gmail.com
# License: MIT
#
# Part of https://github.com/jaclu/spd
#

#
# Since all functions end up int the same namespace,
# ensure that all your functions and global variables
# are unique for this module, adding a short prefix based on script name,
# to ensure no other module will have colliding function names.
#
# Global variables should also be given thought, since if multiple modules
# are being loaded, then a task is called, a generically labeled global
# might have been changed by another module, so try to prefix globals with
# something unique for that module.
#
# Try to be a good citizen and unset "local" variables inside functions,
# when it is exited, since ash does not have the concept of local variables :(
#

#==========================================================
#
#     Messaging and Error display
#
#==========================================================

error_msg() {
    #
    #  Param 1 - error msg
    #  Param 2 - Optional, defaults to 1, if not 0 this will exit
    #
    msg=$1
    err_code=${2:-1}

    [ -z "$msg" ] && error_msg "error_msg() with no param"

    case $err_code in

    '' | *[!0-9]*)
        printf "PARAM ERROR: error_msg() Non numeric err_code given "
        echo "[$err_code] changed into 1"
        err_code=1
        ;;

    *) ;;

    esac

    printf '\nERROR: %b\n\n' "$msg"

    clear_work_dir # clear tmp extract dir

    # since we are exiting, no point in unseting local variables.
    exit "$err_code"
}

warning_msg() {
    msg=$1

    [ -z "$msg" ] && error_msg "warning_msg() with no param"
    printf '\nWARNING: %b\n\n' "$msg"

    unset msg
}

#
# Only displayed if run with param -v
#
verbose_msg() {
    msg=$1

    [ -z "$msg" ] && error_msg "verbose_msg() with no param"
    [ "$p_verbose" = "1" ] && printf 'VERBOSE: %b\n' "$msg"

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
    [ "${#msg}" -ne "$((${#msg} / 2 * 2))" ] && msg=" $msg"

    if [ "${#msg}" -ge "$max_length" ]; then
        # if string is to long, dont use padding
        pad_str=""
    else
        pad_length=$(((max_length - ${#msg}) / 2))
        # posix friendly way of generating x instances of a char
        pad_str=$(head -c $pad_length </dev/zero | tr '\0' ' ')
    fi

    border_line="+$(head -c $max_length </dev/zero | tr '\0' '=')+"

    #
    # TODO:  When generating the spacer padding as a variable,
    # it only translates to one space, but if used as an expression,
    # all spaces are generated
    #
    #spacer_line="|$( head -c $max_length  < /dev/zero | tr '\0' ' ' )|"

    echo "$border_line"
    echo "|$(head -c $max_length </dev/zero | tr '\0' ' ')|"
    echo "|$pad_str$msg$pad_str|"
    echo "|$(head -c $max_length </dev/zero | tr '\0' ' ')|"
    echo "$border_line"
    echo

    unset msg
    unset max_length
    unset pad_str
    unset pad_length
    unset border_line
}

msg_2() {
    echo "=== $1 ==="
}

msg_3() {
    echo "--- $1 ---"
}

#==========================================================
#
#     General public functions
#
#==========================================================

#
#  Some boolean checks
#
is_ish() {
    test -d /proc/ish
}

is_aok_kernel() {
    grep -qi aok /proc/ish/version 2>/dev/null
}

is_debian() {
    test -f /etc/debian_version
}

is_alpine() {
    test -f /etc/alpine-release
}

check_abort() {
    #
    # Check if actions can be done in this environment
    #
    # echo ">> check_abort() - SPD_ABORT=$SPD_ABORT"

    [ "$SPD_ABORT" != "1" ] && return

    if [ "$SPD_TASK_DISPLAY" != "1" ]; then
        msg_2 "SPD_ABORT=1"
        error_msg "This prevents any action from being taken"
    fi
    return 0 # indicate the check indicated unsuitable environment
}

detect_env() {
    # msg_2 ">> detect_env()"
    #
    #  Some constants
    #
    os_type_ish="ish"
    os_type_Linux='Linux'
    os_type_Darwin='Darwin'

    kernel_ish="ish-kernel"
    kernel_ish_aok="ish-aok"

    # distro_family_debian='debian'

    distro_ish_alpine="ish-alpine"
    distro_ish_debian='ish-debian'
    distro_ubuntu='ubuntu'
    distro_MacOS='macos'

    if is_debian; then
        # Uses Debian apt as package manager, filtering out hint that apt
        # is unavailable sometimes pressent in iSH FS
        pkg_add="apt install -y -f"
        pkg_remove="apt remove -y"
        pkg_installed="dpkg -i"
        pkgs_update="apt update"
        pkgs_upgrade="apt upgrade"
        #elif [ -n "$(command -v apk)" ]; then
    else
        # Uses Alpine apk package manager
        pkg_add="apk add"
        pkg_remove="apk del"
        pkg_installed="apk info -e"
        pkgs_update="apk update && apk fix"
        pkgs_upgrade="apk upgrade"
    #else
    #    echo
    #    echo "ERROR Failed to identify package manager!"
    #    exit 1
    fi

    #
    #  Detect environment
    #
    if is_ish; then
        cfg_os_type=$os_type_ish
        # cfg_distro=$distro_alpine
        if is_aok_kernel; then
            cfg_kernel=$kernel_ish_aok
            is_debian && cfg_distro=$distro_ish_debian
        else
            cfg_kernel=$kernel_ish
        fi
        if is_alpine; then
            cfg_distro="$distro_ish_alpine"
        elif is_debian; then
            cfg_distro="$distro_ish_debian"
        else
            error_msg "Unrecognized iSH FS"
        fi

    else
        case "$(uname)" in

        "$os_type_Linux")
            cfg_os_type=$os_type_Linux
            if is_debian; then
                cfg_distro_family=distro_family_debian
                if lsb_release -a 2>/dev/null | grep -qi ubuntu; then
                    cfg_distro=$distro_ubuntu
                fi
            fi
            ;;

        "$os_type_Darwin")
            cfg_os_type=$os_type_Darwin
            cfg_distro=$distro_MacOS
            ;;

        *)
            echo
            echo "ERROR: Failed to detect environment"
            exit 1
            ;;

        esac
    fi

    unset os_type_ish
    unset os_type_Linux
    unset os_type_Darwin
    unset kernel_ish
    unset kernel_ish_aok
    unset distro_ish_debian
    unset distro_ubuntu
    unset distro_MacOS
}

#
# See samples/config/Config.md for explanation how config files are
# processed.
#
read_config() {
    # msg_2 ">> read_config()"
    detect_env

    #
    # the config files are located in $DEPLOY_PATH/custom/config/
    # and have the extension .cfg
    # In order to lowercase the cfg file names when they depend
    # on env variables we only give the base name of the
    # config file below
    #
    _read_cfg_file defaults 1

    [ -n "$cfg_os_type" ] && _read_cfg_file "$cfg_os_type"
    [ -n "$cfg_kernel" ] && _read_cfg_file "$cfg_kernel"
    [ -n "$cfg_distro_family" ] && _read_cfg_file "$cfg_distro_family"
    [ -n "$cfg_distro" ] && _read_cfg_file "$cfg_distro"

    _read_cfg_file "$(hostname | sed 's/\./ /' | awk '{print $1}')"

    _read_cfg_file settings-last

    [ -n "$p_verbose" ] && echo # White space after listing config files parsed
}

#--

run_as_root() {
    #  if started by user account, execute again as root
    if [ "$(whoami)" != "root" ]; then
        msg_2 "Executing $0 as root"
        # using $0 instead of full path makes location not hardcoded
        if ! sudo "$0" "$@"; then
            error_msg "Failed to sudo run: $0"
        fi
        # terminate the user initiated instance
        exit 0
    fi
}

repo_update() {
    [ -z "$pkgs_update" ] && error_msg "No pkgs_update defined" 1

    $pkgs_update
}

repo_upgrade() {
    [ -z "$pkgs_upgrade" ] && error_msg "No pkgs_upgrade defined" 1

    $pkgs_upgrade
}

pkg_present() {
    [ -z "$pkg_installed" ] && error_msg "No pkg_installed defined" 1

    if [ -n "$($pkg_installed "$1" 2>/dev/null)" ]; then
        return 0 # was found
    else
        return 1 #  NOT found
    fi
}

pkg_install() {
    pi_pkgs="$1"
    [ -z "$pkg_add" ] && error_msg "No pkg_add defined" 1

    # shellcheck disable=SC2086
    $pkg_add $pi_pkgs
    unset pi_pkgs
}

pkg_remove() {
    pr_pkgs="$1"
    [ -z "$pkg_remove" ] && error_msg "No pkg_add defined" 1

    # shellcheck disable=SC2086
    $pkg_remove $pr_pkgs
    unset pr_pkgs
}

expand_deploy_path() {
    #
    #  Path not starting with / are assumed to be relative to
    #  $DEPLOY_PATH
    #
    this_path="$1"
    char_1=$(echo "$this_path" | head -c1)

    if [ "$char_1" = "/" ]; then
        echo "$this_path"
    elif [ -n "$this_path" ]; then
        expanded_path="$DEPLOY_PATH/$this_path"
        echo "$expanded_path"
        verbose_msg "$this_path expanded into: $expanded_path"
    fi

    unset this_path
    unset char_1
    unset expanded_path
}

#
# Installs listed package if not already installed, 2nd optional param is
# a message that is displayed if this is installed, default is to use
# "Installing dependency xxx"
# So only one dependency per line!
#
# returns
#     0 if package was already installed
#     1 if package was installed now
#
ensure_installed() {
    # is_debian && return

    pkg=$1
    msg=$2
    ret_val=0

    test -z "$pkg" && error_msg "ensure_installed() called with no param!"
    test -z "$msg" && msg="Installing dependency $pkg"

    pkg_present "$pkg" || msg_3 "$msg"
    [ "$SPD_TASK_DISPLAY" = "1" ] && return

    if ! pkg_present "$pkg"; then
        pkg_install "$pkg"
        ret_val=1
    fi

    unset pkg
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
# in work mode, this fails if SPD_SHELL is not present.
# This does not install the shell, it just verifies if it is there or not.
#
ensure_shell_is_installed() {
    SHELL_NAME=$1

    [ -z "$SHELL_NAME" ] && error_msg "ensure_shell_is_installed() - no shell parameter!"
    if [ "$SPD_TASK_DISPLAY" = "1" ]; then
        test -x "$SHELL_NAME" || warning_msg "$SHELL_NAME not found\n>>>< Make sure it gets installed! ><<\n"
    else
        test -f "$SHELL_NAME" || error_msg "Shell not found: $SHELL_NAME"
        test -x "$SHELL_NAME" || error_msg "Shell not executable: $SHELL_NAME"
    fi

    unset SHELL_NAME
}

#
#  Handles a temp dir, for untaring stuff etc
#  calling it without param, just removes tmp dir
#  and all its content. Param 1 requests a new
#  tmp dir to be created
#
clear_work_dir() {
    new_space=$1

    extract_location="/tmp/deploy-ish-$$" # based on pid
    rm $extract_location -rf 2>/dev/null

    case "$new_space" in

    "1")
        mkdir -p $extract_location
        cd $extract_location || error_msg "clear_work_dir() could not cd !"
        ;;

    "") ;;

    *)
        echo
        echo "ERROR: clear_work_dir() accepted params: nothing|1"
        exit 1
        ;;

    esac

    unset new_space
}

#
#  Restore $home_dir unless $unpacked_ptr points to an existing file.
#  If $save_current is 1, current home dir is moved to $home_dir-OLD and
#  kept, otherwise current home-dir is emptied if extract succeeds.
#
unpack_home_dir() {
    msg_txt=$1
    username=$2
    home_dir=$3
    fhome_packed=$4
    unpacked_ptr=$5
    save_current=$6
    old_home_dir="$home_dir-OLD"

    [ "$save_current" != "1" ] && save_current=0

    # (mostly) unverified parameters
    #verbose_msg "unpack_home_dir(username=$username, home=$home_dir, fhome_packed=$fhome_packed, unpacked_ptr=$unpacked_ptr, save_current=$save_current)"
    # TODO: verify that this split param approach displays as intended!
    verbose_msg "$(
        printf "unpack_home_dir(username=%s, home=" "$username"
        printf "%s, fhome_packed=%s, , unpacked_ptr=" "$home_dir" "$fhome_packed"
        echo "$unpacked_ptr, save_current=$save_current)"
    )"

    #
    #  Parameter checks
    #
    # Some of the checks below are ignored when $SPD_TASK_DISPLAY is 1 ie just informing what will happen
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
    if [ -z "$fhome_packed" ] || [ "$fhome_packed" = "1" ]; then
        error_msg "unpack_home_dir($username, $home_dir,) - No file to be extracted given"
    fi
    ! test -f "$fhome_packed" && error_msg "file not found:\n[$fhome_packed]"

    case "$unpacked_ptr" in

    "0" | "1")
        # Not actual error, no unpacked_ptr given so save_current got shifted here"
        unpacked_ptr=""
        ;;

    *) ;;

    esac
    #
    #  Actual work starts
    #
    msg_2 "$msg_txt" # TODO: make $msg_txt a param!
    if [ "$save_current" = "1" ]; then
        do_unpack=1 # always restore
    else
        if test -f "$unpacked_ptr"; then
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
            [ -z "$(command -v unzip)" ] && ensure_installed unzip
            clear_work_dir 1
            msg_3 "Extracting"
            echo "$fhome_packed"
            if [ "${fhome_packed#*zip}" != "$fhome_packed" ]; then
                # Seems to be a zip file
                # Give username access to extract location, so that
                # the right user can unzip the files
                chown "$username":"$username" $extract_location
                su "$username" -c "unzip -q $fhome_packed"
                err_code="$?"
                [ "$err_code" -ne 0 ] && error_msg "Failed to unzip ($err_code)"
            else
                # Seems to be a tar ball
                ! tar xfz "$fhome_packed" 2>/dev/null && error_msg "Failed to unpack tarball"
            fi
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
                msg_3 "Replacing $home_dir"
                cd "$home_dir" || error_msg "Failed to cd to $home_dir"
                cd ..
                rm "$home_dir" -rf
                mv "$extract_location/$username" .
            fi
            msg_3 "$home_dir restored"
            clear_work_dir # Remove tmp directory
        fi
    fi

    unset err_code
    unset username
    unset home_dir
    unset fhome_packed
    unset unpacked_ptr
    unset save_current
    unset old_home_dir
}

parse_command_line() {
    #
    # Only process cmd line for initial_script
    # The p_ variables should not be unset!
    p_cfg=0
    p_help=0
    p_verbose=0
    SPD_TASK_DISPLAY=1
    while [ -n "$1" ]; do

        case "$1" in

        "-?" | "-h" | "--help")
            p_help=1
            unset SPD_TASK_DISPLAY
            ;;

        "-v" | "--verbose")
            p_verbose=1
            ;;

        "-c")
            p_cfg=1
            ;;

        "-x")
            SPD_TASK_DISPLAY=0
            ;;

        *)
            echo "WARNING: Unsupported param!: [$1]"
            ;;

        esac
        shift
    done

    #
    # This will not happen by default when run as bin/deploy-ish.sh!
    # So in that file read_config.sh is sourced directly.
    # If you were to run bin/deploy-ish.sh with -c nothing bad happens,
    # the configs will just be parsed twice
    #

    if [ $p_cfg -eq 1 ]; then
        # shellcheck disable=SC1091
        read_config
    fi

    #
    # This is checked after all config files are processed, so if you really want to, you can
    # override this in a later config file....
    # If help is requested we will continue despite SPD_ABORT=1
    # Since nothing will be changed, and it helps testing scripts on non supported platforms.
    #
    if [ "$SPD_TASK_DISPLAY" = "0" ] && [ $p_help = 0 ]; then
        [ "$SPD_ABORT" = "1" ] && error_msg "SPD_ABORT=1 detected. Will not run on this system."
    fi
}

#=====================================================================
#
# _run_this() & _display_help()
# are only run in standalone mode, so no risk for wrong same named function
# being called...
#
# In standalone mode, this will be run from See "main" part at end of
# extras/utils.sh, it first expands parameters,
# then either displays help or runs the task(-s)
#
_run_this() {
    #
    # Perform the task / tasks independently, convenient for testing
    # and debugging.
    #
    # loop over lines in $script_tasks
    #
    set -f
    IFS='
'
    # next line can not use quotes
    # shellcheck disable=SC2086,SC2154
    set -- $script_tasks
    while [ -n "$1" ]; do
        # execute first word from line
        IFS=' '
        $1
        # pop first line from lines, including potential description of task
        IFS='
'
        shift
    done
    set +f
    unset IFS
}

#==========================================================
#
#   Internals
#
#==========================================================

_read_cfg_file() {
    cfg_file="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
    [ -z "$cfg_file" ] && error_msg "_read_cfg_file() called with no param!"

    # verbose_msg "Looking for config_file: ${CONFIG_PATH}/$cfg_file"

    must_exist="${2:-0}"

    cfg_file="$CONFIG_PATH/${cfg_file}.cfg"

    if [ -f "$cfg_file" ]; then
        verbose_msg "will read: $cfg_file"
        #shellcheck disable=SC1090
        . "$cfg_file"
    elif [ "$must_exist" = "1" ]; then
        error_msg "_read_cfg_file($cfg_file) obligatory config file not found!"
    else
        verbose_msg "NOT found: $cfg_file"
    fi

    unset cfg_file
    unset musut_exist
}

#==========================================================
#
#     Main
#
#==========================================================

if test -z "$DEPLOY_PATH"; then
    error_msg "ERROR: utils.sh MUST be sourced!"
fi

[ -z "$CONFIG_PATH" ] && CONFIG_PATH="${DEPLOY_PATH}/custom/config"
