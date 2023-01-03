#!/bin/sh
#
#  This script is controlled from extras/script_base.sh this specific
#  script only contains settings and overrides.
#

#=====================================================================
#
#  All task scripts must define the following two variables:
#  script_tasks:
#    List tasks provided by this script. If multiple one per line single
#    multi-line string first word is task name, rest is optional
#    description of task
#  script_description
#    Short summary what this script does (for the help display)
#    Single multi line string.
#
#=====================================================================

# shellcheck disable=SC2034
script_tasks="task_replace_some_etc_files  - replaces hosts and repositories if so requested
task_patch_etc_files         - Fixes some files with issues"
script_description="Will fix /etc/inittab, and if so requested replace some /etc files"



#=====================================================================
#
#   Describe additional parameters, if none are used don't define
#   help_local_params() script_base.sh will handle that condition.
#
#=====================================================================

help_local_parameters() {
    echo "SPD_FILE_HOSTS$(
        test -z "$SPD_FILE_HOSTS" \
        && echo '        - will replace /etc/hots' \
        || echo "=$SPD_FILE_HOSTS" )"
    echo "SPD_FILE_REPOSITORIES$(
        test -z "$SPD_FILE_REPOSITORIES" \
        && echo ' - will replace /etc/apk/repositories' \
        || echo "=$SPD_FILE_REPOSITORIES" )"
}



#=====================================================================
#
#  Task (public) functions
#
#  Assumed to start with task_ and then describe the task in a sufficiently
#  unique way to give an idea of what this task does,
#  and not collide with other modules.
#  Use a short prefix unique for your module.
#
#=====================================================================

task_replace_some_etc_files() {
    verbose_msg "task_replace_some_etc_files()"

    _tef_expand_all_deploy_paths

    msg_2 "Replacing some files in /etc"
    # If the config file is not found, no action will be taken
    check_abort

    [ -n "$SPD_FILE_HOSTS" ] &&  _tef_copy_etc_file "$SPD_FILE_HOSTS" /etc/hosts
    echo
}

task_patch_etc_files() {
    msg_2 "Patching some /etc files"
    check_abort
    # _tef_fix_inittab
    echo
}



#=====================================================================
#
#   Internal functions, start with _ and abbreviation of script name to make it
#   obvious they should not be called by other modules.
#
#=====================================================================

_tef_expand_all_deploy_paths() {
    #
    # Expanding path variables that are either absolute or relative
    # related to the deploy-path
    #
    SPD_FILE_HOSTS=$(expand_deploy_path "$SPD_FILE_HOSTS")
    SPD_FILE_REPOSITORIES=$(expand_deploy_path "$SPD_FILE_REPOSITORIES")
}


_tef_copy_etc_file() {

    tcef_src="$1"
    tcef_dst="$2"
    tcef_extra="$3"

    if [ -n "$tcef_extra" ]; then
        error_msg "_tef_copy_etc_file($tcef_src, $tcef_dst) [$tcef_extra]" \
                  "more than 2 params given!"
    fi
    verbose_msg "_tef_copy_etc_file($tcef_src, $tcef_dst)"
    if [ -n "$tcef_src" ]; then
        msg_3 "$tcef_dst"
        if [ ! -f "$tcef_src" ]; then
            error_msg "_tef_copy_etc_file() src_file[$tcef_src] " \
                      "NOT FOUND!\n$tcef_src"
        fi
        if [ "$SPD_TASK_DISPLAY" != "1" ]; then
            rm "$tcef_dst" # to avoid incomplete removal of prev vers of file
            cp "$tcef_src" "$tcef_dst"
            echo "$tcef_src"
        elif [ "$SPD_TASK_DISPLAY" = "1" ] \
                && [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
            echo "Will NOT be modified"
        fi
    fi
    unset tcef_dst
    unset tcef_src
    unset tcef_extra
}


_tef_not_fix_inittab() {
    tfi_inittab_file="/etc/inittab"
    verbose_msg "_tef_cleanup_inittab()"
     msg_3 "Inspecting $tfi_inittab_file"

    # Since iSH has no concept of consoles getty lines are pointless
    if grep -q 'getty' "$tfi_inittab_file"; then
        msg_3 "Removing gettys"
        if [ "$SPD_TASK_DISPLAY" != "1" ]; then
           sed -i '/getty/d' "$tfi_inittab_file"
            echo "done!"
        else
            echo "will happen"
       fi
    fi

    # Get rid of mostly non functional openrc config lines
    tfi_ok_line="::sysinit:/sbin/openrc default"
    if grep openrc "$tfi_inittab_file" | grep -q -v "$tfi_ok_line"; then
        msg_3 "Fixing openrc related content"
        if ! grep -q "$tfi_ok_line" /etc/inittab ; then
            if [ "$SPD_TASK_DISPLAY" != "1" ]; then
                sed -i '/::sysinit/d' "$tfi_inittab_file"
                sed -i '/::wait:/d' "$tfi_inittab_file"
                echo "$tfi_ok_line"  >> "$tfi_inittab_file"
                echo "done!"
            else
                echo "will happen"
            fi
        else
            echo "Patch already applied!"
        fi
    fi

    unset tfi_inittab_file
    unset tfi_ok_line
}


#=====================================================================
#
#   Run this script via extras/script_base.sh
#
#=====================================================================

script_dir="$(dirname "$0")"

# shellcheck disable=SC1091
[ -z "$SPD_INITIAL_SCRIPT" ] && . "${script_dir}/tools/script_base.sh"

unset script_dir
