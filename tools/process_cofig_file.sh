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

pcf_verify_config_file() {
    _vcf_f_cfg=$1
    _vcf_in_list=0
    _vcf_first_line=true
    while IFS= read -r _vcf_line; do
        # Trim leading whitespace
        _vcf_line=${_vcf_line#"${_vcf_line%%[![:space:]]*}"}

        $_vcf_first_line && {
            [ "$_vcf_line" != "---" ] && {
                printf 'ERROR: first line in yaml config file must be: "---"\n' >&2
                exit 1
            }
            _vcf_first_line=false
            continue
        }
        case $_vcf_in_list in
            1)
                case $_vcf_line in
                    '-'\ *) continue ;; # list item
                    '#'*) continue ;;   # comment
                    *':')
                        _vcf_in_list=1
                        continue
                        ;;                        # bare key: list follows
                    *':'* | '') _vcf_in_list=0 ;; # blank line or nev key: value scalar
                    *)
                        printf 'ERROR: invalid list item: [%s]\n' \
                            "$_vcf_line" >&2
                        exit 1
                        ;;
                esac
                ;;
            *)
                case $_vcf_line in
                    '' | '#'*) continue ;; # in this case both comment and blanks ignored
                    [A-Za-z_][A-Za-z0-9_]*':'\ * | \
                        [A-Za-z_][A-Za-z0-9_]*':')
                        # Valid key: or key: value line
                        case $_vcf_line in
                            *':') _vcf_in_list=1 ;;
                            *) _vcf_in_list=0 ;;
                        esac
                        ;;
                    *)
                        printf 'invalid config line: [%s]\n' "$_vcf_line" >&2
                        exit 1
                        ;;
                esac
                ;;
        esac
    done <"$_vcf_f_cfg"
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
                eval "$_pcf_key=\$_val"
                ;;
        esac

    done <"$_pcf_f_cfg"

    pcf_flush_pending
    return 0
}

read_config_file() {
    _rcf_f_cfg="$1"
    pcf_verify_config_file "$_rcf_f_cfg"
    pcf_parse_config_file "$_rcf_f_cfg"
}

#
# Test
#
d_here="$(dirname "$(realpath "$0")")"
read_config_file "$d_here/config.yml"

echo "Verify variables retrieved"
# shellcheck disable=SC2154
{
    echo "SPD_FOO:          [$SPD_FOO]"
    echo "SPD_SUNE:         [$SPD_SUNE]"
    echo "HEPP (excluded):  [$HEPP]"
    echo "SPD_LST_1:        [$SPD_LST_1]"
    echo "SPD_LST_2:        [$SPD_LST_2]"
    echo "SPD_LST_3:        [$SPD_LST_3]"
}
