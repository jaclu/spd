#!/bin/sh

#
# Part of https://github.com/jaclu/spd
#
# Copyright (c) 2026 Jacob Lundqvist <jacob.lndqvist@gmail.com>
# License: MIT
#
# iSH-specific startup workaround for occasional missing or broken core
# /dev I/O devices.
#
# Validates and repairs standard I/O device nodes when required:
#   /dev/null, /dev/stdin, /dev/stdout, /dev/stderr
#
# Parses yaml config files in pure posix, no external dependencies
#

# Strip inline comment and surrounding whitespace from a value
# e.g.  "bar" # comment  ->  bar
pycf_strip_inline_comment() {
    _sic_val=$1
    # Remove optional surrounding double-quotes first, then strip # comment
    # We process: remove leading/trailing quotes if paired, then cut at ' #'
    case $_sic_val in
        \"*\")
            _sic_val=${_sic_val#\"}
            _sic_val=${_sic_val%\"}
            ;;
        *) ;;
    esac
    # Strip trailing inline comment (space-hash boundary)
    case $_sic_val in
        *' #'*) _sic_val=${_sic_val%%' #'*} ;;
        *'	#'*) _sic_val=${_sic_val%%'	#'*} ;; # tab-hash
        *) ;;
    esac
    # Trim trailing whitespace
    while case $_sic_val in *' ' | *'	') true ;; *) false ;; esac do
        _sic_val=${_sic_val%?}
    done
    printf '%s' "$_sic_val"
}

pycf_expand_template() {
    _pet_val=$1
    # Replace {{ VAR_NAME }} with ${VAR_NAME}
    # Handles optional whitespace inside the braces
    while case $_pet_val in *'{{'*'}}'*) true ;; *) false ;; esac do
        _pet_before=${_pet_val%%'{{' *}
        _pet_rest=${_pet_val#*'{{'}
        # trim leading whitespace inside braces
        _pet_rest=${_pet_rest#"${_pet_rest%%[![:space:]]*}"}
        _pet_varname=${_pet_rest%%'}'*}
        # trim trailing whitespace from varname
        while case $_pet_varname in *' ' | *'	') true ;; *) false ;; esac do
            _pet_varname=${_pet_varname%?}
        done
        _pet_after=${_pet_rest#*'}}'}
        _pet_val="${_pet_before}\${${_pet_varname}}${_pet_after}"
    done
    printf '%s' "$_pet_val"
}

pycf_flush_pending() {
    # Uses: $_fp_var, $_fp_content  -- sets them back to empty
    [ -z "$_fp_var" ] && [ -n "$_fp_content" ] && {
        printf 'ERROR: pycf_flush_pending() - content but no var\n' >&2
        exit 1
    }
    [ -n "$_fp_var" ] && {
        eval "$_fp_var=\$_fp_content"
    }
    _fp_var=''
    _fp_content=''
}

pycf_parse_config_file() {
    _pcf_f_cfg=$1
    pycf_flush_pending

    while IFS= read -r _pcf_line; do
        # Trim leading whitespace
        _pcf_trimmed=${_pcf_line#"${_pcf_line%%[![:space:]]*}"}

        case $_pcf_trimmed in
            '---' | '' | '#'*) continue ;; # skip headerline, blank and comments
            *) ;;
        esac

        # List item (must check before key detection)
        case $_pcf_trimmed in
            '-'\ *)
                [ -n "$_fp_var" ] || {
                    printf 'ERROR: list item without active list key: %s\n' \
                        "$_pcf_line" >&2
                    exit 1
                }
                _pcf_item=${_pcf_trimmed#'- '}
                _pcf_item=$(pycf_strip_inline_comment "$_pcf_item")
                _pcf_item=$(pycf_expand_template "$_pcf_item")
                # Append with space separator (first item has no leading space)
                if [ -z "$_fp_content" ]; then
                    _fp_content=$_pcf_item
                else
                    _fp_content="$_fp_content $_pcf_item"
                fi
                continue
                ;;
            *) ;;
        esac

        # Any new key: flush whatever was pending
        pycf_flush_pending

        # Extract key and raw value
        _pcf_key=${_pcf_trimmed%%':'*}
        _pcf_rest=${_pcf_trimmed#*':'} # everything after first colon

        # Trim leading whitespace from rest
        _pcf_rest=${_pcf_rest#"${_pcf_rest%%[![:space:]]*}"}

        # Validate key characters (verify already ran, but be safe)
        case $_pcf_key in
            [A-Za-z_][A-Za-z0-9_]*) ;;
            *)
                printf 'ERROR: bad key [%s]\n' "$_pcf_key" >&2
                exit 1
                ;;
        esac

        # Enforce SPD_ prefix; warn and skip others
        case $_pcf_key in
            SPD_*) ;;
            *)
                printf 'WARNING: Config [%s]: ignoring non-SPD_ key: %s\n' \
                    "$_pcf_f_cfg" "$_pcf_key" >&2
                continue
                ;;
        esac

        # Empty rest -> list follows
        case $_pcf_rest in
            '' | '#'*)
                _fp_var=$_pcf_key
                _fp_content=''
                ;;
            *)
                # Scalar value on same line
                _val=$(pycf_strip_inline_comment "$_pcf_rest")
                _val=$(pycf_expand_template "$_val")
                eval "$_pcf_key=\$_val"
                ;;
        esac

    done <"$_pcf_f_cfg"

    pycf_flush_pending
    return 0
}

pycf_extract_ref() {
    s=${1#\$\{} # remove leading "${"
    s=${s%\}}   # remove trailing "}"
    printf '%s' "$s"
}

pycf_not_done_extract_all_variable_references() {
    echo "$1" \
        | awk '{
            while (match($0, /\$\{[A-Za-z_][A-Za-z0-9_]*\}/)) {
                v = substr($0, RSTART+2, RLENGTH-3)
                print v
                $0 = substr($0, RSTART + RLENGTH)
            }
        }'
}

pycf_display_references() {
    # shellcheck disable=SC2086
    set -- $pycf_expanded_items

    first=1
    for x; do
        if [ "$first" -eq 1 ]; then
            printf '%s' "$x"
            first=0
        else
            printf ' -> %s' "$x"
        fi
    done
    printf '\n'
}

pycf_check_circular_reference() {
    #
    #  First extracts references, if multiple, process them one at a time in a
    #  new call to expand_config_var after resetting all states except
    #  pycf_expansion_step, if just a single, store it and return
    #  stores each reference, and aborts if something points to an already
    #  referred variable
    #
    _pcr_item=$(pycf_extract_ref "$1")
    dbg_msg "pycf_check_circular_reference() [$(pycf_extract_ref "$1")]" 9
    [ -z "$_pcr_item" ] && return # empty param
    case "$pycf_expanded_items" in
        *${_pcr_item}*)
            echo
            pycf_expanded_items="$pycf_expanded_items $_pcr_item"
            lbl_1 "Circular reference back to a previous variable name"
            pycf_display_references
            err_msg "Circular config expansion back to $_pcr_item"
            ;;
        *) pycf_expanded_items="$pycf_expanded_items $_pcr_item" ;;
    esac
}

#===============================================================
#
#   Public content
#
#===============================================================

#
# Processes a yaml-style config file and assigns the corresponding posix variable
#
parse_yaml_config_file() {
    _rcf_f_cfg="$1"
    # shellcheck disable=SC2154 # module_name defined in caller
    if [ -f "$_rcf_f_cfg" ]; then
        dbg_msg "Processing config-file: $(relative_path "$_rcf_f_cfg")" 5
        pycf_parse_config_file "$_rcf_f_cfg"
    else
        dbg_msg "Config file not found: $_rcf_f_cfg" 3
    fi
}

#
# To handle nested referrals, each script using config file derived variables
# should run this for each of the variables it indends to use, before using them.
# Referrals are not expanded until this is done, this approach handles nested referrals
# and allows referrals to be overridden in other config files.
# Since expansion is recursive, until no more ${} constructs remains,
# it does not matter in what order variables are expanded.
# Circular references like SPD_HOME_DIR -> SPD_UNAME -> SPD_HOME_DIR will be detected
# and throws an error.
#
# Sample usage
# expand_config_var SPD_HOME_DIR
# expand_config_var SPD_UNAME
#
# The first line will handle the case of the config: SPD_HOME_DIR: "/home/{{ SPD_UNAME }}"
# even if SPD_UNAME itself is also a nested variable. SPD_UNAME can be expanded
# after SPD_HOME_DIR, so expansion order does not depend on how they are nested
#

expand_config_var() {
    _ecv_varname=$1
    _ecv_default="$2"
    _ecv_maintain_expansion_depth="$3"

    [ -z "$_ecv_maintain_expansion_depth" ] && pycf_expansion_step=0
    pycf_expanded_items="$_ecv_varname"

    dbg_msg "expand_config_var() [$_ecv_varname] [$_ecv_default]" 9
    while eval "_ecv_val=\"\$$_ecv_varname\""; do
        dbg_msg "  _ecv_val[$_ecv_val]" 9
        pycf_check_circular_reference "$_ecv_val"
        [ "$_ecv_val" = "${_ecv_val#*\$\{}" ] && break
        pycf_expansion_step=$((pycf_expansion_step + 1))
        [ "$pycf_expansion_step" -ge "$pycf_expansion_steps_max" ] && {
            m="expand_config_var() - max depth reahced,"
            m="$m aborting to avoid infinete recursion"
            err_msg "$m"
        }
        eval "$_ecv_varname=\"$_ecv_val\""
    done
    [ -z "$_ecv_val" ] && _ecv_val="$_ecv_default" # ok if _ecv_default is empty
    eval "$_ecv_varname=\"$_ecv_val\""
}

#=====================================================================
#
#   Main
#
#=====================================================================

pycf_expansion_steps_max=50

# D_REPO is set by $0 to give the path to the repository
[ -z "$D_REPO" ] && {
    printf '\n\nERROR: tools/process-yaml-config_file.sh must be sourced.\n' >&2
    exit 1
}
