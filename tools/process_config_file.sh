#!/bin/sh

# Strip inline comment and surrounding whitespace from a value
# e.g.  "bar" # comment  ->  bar
pcf_strip_inline_comment() {
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

pcf_expand_template() {
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

pcf_flush_pending() {
    # Uses: $_fp_var, $_fp_content  -- sets them back to empty
    [ -z "$_fp_var" ] && [ -n "$_fp_content" ] && {
        printf 'ERROR: pcf_flush_pending() - content but no var\n' >&2
        exit 1
    }
    [ -n "$_fp_var" ] && {
        eval "$_fp_var=\$_fp_content"
    }
    _fp_var=''
    _fp_content=''
}

pcf_parse_config_file() {
    _pcf_f_cfg=$1
    pcf_flush_pending

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
                _pcf_item=$(pcf_strip_inline_comment "$_pcf_item")
                _pcf_item=$(pcf_expand_template "$_pcf_item")
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
        pcf_flush_pending

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
                _val=$(pcf_strip_inline_comment "$_pcf_rest")
                _val=$(pcf_expand_template "$_val")
                eval "$_pcf_key=\$_val"
                ;;
        esac

    done <"$_pcf_f_cfg"

    pcf_flush_pending
    return 0
}

#===============================================================
#
#   Public content
#
#===============================================================

#
# Processes a yaml-style config file and assigns the corresponding posix variable
#
read_config_file() {
    _rcf_f_cfg="$1"
    msg_dbg "Processing: $_rcf_f_cfg" 1
    if [ -f "$_rcf_f_cfg" ]; then
        msg_dbg "Processing config-file: $(relative_path "$_rcf_f_cfg")" 1
        pcf_parse_config_file "$_rcf_f_cfg"
    else
        msg_dbg "Config file not found: $_rcf_f_cfg" 2
    fi
}

#
# To handle nested referals, each script using config file derived variables
# should run this for each of the variables it indends to use, before using them.
# Referals are not expanded until this is done, this aproach handles nested referals
# and allows referals to be overriden in other config files.
# Since expansion is recursive, until no more ${} constructs remaini,
# it does not matter in what order variables are expanded
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
    _ev_varname=$1
    while eval "_ev_val=\"\$$_ev_varname\""; do
        # shellcheck disable=SC2154 # _ev_val defined in eval above
        [ "$_ev_val" = "${_ev_val#*\$\{}" ] && break
        eval "$_ev_varname=\"$_ev_val\""
    done
}

# D_REPO is set by $0 to give the path to the repository
[ -n "$D_REPO" ] || {
    echo "ERROR: This can not be run directly"
    exit 1
}
