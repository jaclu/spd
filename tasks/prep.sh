#!/bin/sh

verify_config_file() {
    _f_cfg=$1
    in_q=0

    while IFS= read -r line; do

        # trim leading whitespace once
        line=${line#"${line%%[![:space:]]*}"}

        case $in_q in
            1)
                case $line in
                    \"*)
                        echo "><> List end [$line]"
                        in_q=0
                        continue
                        ;;
                    *)
                        echo "><> List continuation [$line]"
                        continue
                        ;;
                esac
                ;;
            *) ;;
        esac

        case $line in
            '' | \#*) continue ;; # blank lines and comments
            [A-Za-z_][A-Za-z0-9_]*=\"*)
                # foo=" type list start - allow
                in_q=1
                ;;
            [A-Za-z_][A-Za-z0-9_]*=*)
                # foo=bar type line - allow
                ;;
            *)
                printf 'invalid config line: [%s]\n' "$line" >&2
                exit 1
                ;;
        esac

    done <"$_f_cfg"
}

complee_pending_list() {
    echo "><> complee_pending_list() - $1"
    [ -z "$list_var" ] && [ -n "$list_content" ] && {
        echo "ERROR: complee_pending_list() - list_content but no list_var"
        exit 1
    }
    [ -n "$list_var" ] && {
        # echo "  [$list_var] = [$list_content]"
        eval "$list_var=\$list_content"
    }
    # allways clear
    list_var=""
    list_content=""
}

parse_config_file() {
    _f_cfg=$1

    complee_pending_list init
    while IFS= read -r line; do
        # trim leading whitespace once
        line=${line#"${line%%[![:space:]]*}"}

        # trim leading whitespace once
        line=${line#"${line%%[![:space:]]*}"}

        case $line in
            '' | \#*) continue ;; # blank lines and uninented comments

            SPD_*=*)
                complee_pending_list pre-new-spd
                list_var=${line%%=*}
                list_content=${line#*=}
                [ "$list_content" = '"' ] && list_content=''
                ;;

            *=*) # Assignment without propper prefix - ignored
                printf 'WARNING: Config file [%s]\n' "$_f_cfg" >&2
                printf '         Invalid assignment: %s\n' "$line" >&2
                complee_pending_list ignored-assignment
                ;;

            \"*) complee_pending_list final-quote ;;

            [A-Za-z_][A-Za-z0-9_]*)
                [ -n "$list_var" ] || {
                    printf 'ERROR: invalid list item: %s\n' "$line" >&2
                    exit 1
                }
                list_content="$list_content $line"
                ;;

            *) echo "><> left over line type [$line]" ;;

        esac
    done <"$_f_cfg"
    complee_pending_list final
    return 0
}

read_config_file() {
    _f_cfg="$1"
    verify_config_file "$_f_cfg"
    echo
    echo
    parse_config_file "$_f_cfg"
}

#
# Test this
#
d_here="$(dirname "$(realpath "$0")")"

read_config_file "$d_here"/config.cfg

echo "Verify variables retrieved"
#  shellcheck disable=SC2154
{
    echo "SPD_FOO: $SPD_FOO"
    echo "SPD_SUNE: $SPD_SUNE"
    echo "HEPP:    $HEPP"
    echo "SPD_APTS_INSTALL: $SPD_APTS_INSTALL"
    echo "SPD_LST_1 [$SPD_LST_1]"
    echo "SPD_LST_2 [$SPD_LST_2]"
    echo "SPD_LST_3 [$SPD_LST_3]"
}
