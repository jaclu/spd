#!/bin/sh

verify_config_file() {
    _f_cfg=$1
    in_q=0

    while IFS= read -r line; do

        case $in_q in
            1)
                case $line in
                    *'"')
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

        # case $line in
        #     ''|[ 	]*#*) continue ;;
        # esac

        case $line in
            '' | \#*) continue ;;                  # blank lines and uninented comments
            [[:space:]]*[[:space:]]#*) continue ;; # inented comments
            [A-Za-z_][A-Za-z0-9_]*=\"*)
                # foo=" type list start - allow
                echo "><> List start [$line]"
                in_q=1
                continue
                ;;
            [A-Za-z_][A-Za-z0-9_]*=*)
                # foo=bar type line - allow
                echo "><> foo=bar [$line]"
                continue
                ;;
            *)
                printf 'invalid config line: [%s]\n' "$line" >&2
                exit 1
                ;;
        esac

    done <"$_f_cfg"
}

complee_pending_list() {
    [ -z "$list_var" ] && [ -n "$list_content" ] && {
        echo "ERROR: complee_pending_list() - list_content but no list_var"
        exit 1
    }
    [ -n "$list_var" ] && {
        echo "><> complee_pending_list [$list_var] = [$list_content]"
        eval "$list_var=\$list_content"
    }
    # allways clear
    list_var=""
    list_content=""
}

parse_config_file() {
    _f_cfg=$1

    complee_pending_list
    while IFS= read -r line; do
        # Skip blank and comment lines
        case $line in
            '' | \#*) continue ;;                  # blank lines and uninented comments
            [[:space:]]*[[:space:]]#*) continue ;; # inented comments
            *) ;;
        esac

        case $line in
            SPD_*=*)
                # echo "PRSE: Assignment [$line]"
                complee_pending_list
                list_var=${line%%=*}
                list_content=${line#*=}

                # detect start of quoted multiline
                case $list_content in
                    \") list_content='' ;; # start of multiline string
                    *) ;;
                esac
                ;;

            *=*) complee_pending_list ;; # assignment of ignored variable

            # [[:space:]]*[A-Za-z_]*)
            [A-Za-z_]* | [[:space:]]*[A-Za-z_][A-Za-z0-9_]*)
                # list continuation line
                case $list_var in
                    SPD_*)
                        # echo "PRSE: New list item for [$list_var] [$list_content] [$line]"
                        line=${line#"${line%%[![:space:]]*}"}
                        list_content="$list_content $line"
                        ;;
                    *)
                        printf 'invalid list context: %s\n' "$line" >&2
                        exit 1
                        ;;
                esac
                ;;

            [[:space:]]*[[:space:]]'"')
                complee_pending_list
                ;;
            *)
                echo "Ignored line: [$line]"
                ;;
        esac

    done <"$_f_cfg"
    complee_pending_list
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
