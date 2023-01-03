#!/usr/bin/env bash
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
script_tasks="task_replace_files"
script_description="Will replace files with src|dst pairs"



#=====================================================================
#
#   Describe additional parameters, if none are used don't define
#   help_local_params() script_base.sh will handle that condition.
#
#=====================================================================

help_local_parameters() {
    echo "SPD_FILE_REPLACEMENTS$(
        test -z "$SPD_FILE_REPLACEMENTS" \
        && echo '        - shoulld contain pairs of src|dst' \
        || echo "=$SPD_FILE_REPLACEMENTS" )"
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

task_replace_files() {
    verbose_msg "task_replace_files()"

    _trf_expand_all_deploy_paths

    # If the config file is not found, no action will be taken
    check_abort

    for pair in  "${SPD_FILE_REPLACEMENTS[@]}"; do
        echo ">> exracting src"
	echo ">> pair is:[$pair]"
    	src="$(echo "$pair" | cut -d'|'  -f 1)"
	echo ">>src[$src]
	echo ">> Done testing params"
	exit 1
	exit 2
	exit 3

        echo ">> exracting dst"
    	dst="$(echo "$pair" | cut -d'|'  -f 2)"
	echo ">>dst[$dst]
   	msg_2 "Replacing $src with $dst"
    	if [ ! -f "$src" ]; then
	    error_msg "task_replace_files() - src file [$src] NOT found!"
	fi
	if [ -z "$dst" ]; then
	    error_msg "task_replace_files() - no destination given for [$src]"
	fi
	backup_fname="ORIG-$dst"
	if [ ! -f "ORIG-$dst" ]; then
	    msg_2 "Created backup file: $backup_fname"
	    mv "$dst" "$backup_fname"
	else
	    msg_2 "Already present: $backup_fname\n will not be overwritten!"
	fi
	cp "$src" "$dst"
        echo "Copied $src -> $dst"
    done
    echo ">> Loop Done" ; exit 1

    echo
}


#=====================================================================
#
#   Internal functions, start with _ and abbreviation of script name to make it
#   obvious they should not be called by other modules.
#
#=====================================================================

_trf_expand_all_deploy_paths() {
    #
    # Expanding path variables that are either absolute or relative
    # related to the deploy-path
    #

    SPD_FILE_REPLACEMENTS=$(expand_deploy_path "$SPD_FILE_REPLACEMENTS")
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
