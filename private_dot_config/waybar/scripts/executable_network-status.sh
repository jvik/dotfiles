#!/usr/bin/env sh

kind=$1
variant=${2:-leader}

matches_kind() {
    module_kind=$1
    iface=$2

    case "$module_kind" in
        wlan)
            case "$iface" in
                wl*) return 0 ;;
            esac
            ;;
        tether)
            case "$iface" in
                enx*|usb*|rndis*|enp*u[0-9]*) return 0 ;;
            esac
            ;;
        lan)
            case "$iface" in
                eth*|enp*)
                    case "$iface" in
                        enp*u[0-9]*) return 1 ;;
                    esac
                    return 0
                    ;;
            esac
            ;;
    esac

    return 1
}

list_candidates() {
    module_kind=$1

    for path in /sys/class/net/*; do
        iface=${path##*/}
        [ "$iface" = "lo" ] && continue
        matches_kind "$module_kind" "$iface" && printf '%s\n' "$iface"
    done
}

has_global_ip() {
    ip -o addr show up scope global dev "$1" 2>/dev/null | grep -q .
}

select_iface() {
    module_kind=$1
    first_match=
    default_iface=$(ip route show default 2>/dev/null | awk 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')

    if [ -n "$default_iface" ] && matches_kind "$module_kind" "$default_iface" && has_global_ip "$default_iface"; then
        printf '%s\n' "$default_iface"
        return 0
    fi

    for iface in $(list_candidates "$module_kind"); do
        [ -n "$first_match" ] || first_match=$iface
        if has_global_ip "$iface"; then
            printf '%s\n' "$iface"
            return 0
        fi
    done

    printf '%s\n' "$first_match"
}

json_escape() {
    printf '%s' "$1" | awk '
        BEGIN { ORS = "" }
        {
            gsub(/\\/, "\\\\")
            gsub(/"/, "\\\"")
            gsub(/\t/, "\\t")
            printf "%s", $0
        }
    '
}

print_json() {
    text=$1
    class_name=$2
    tooltip=$3

    printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' \
        "$(json_escape "$text")" \
        "$(json_escape "$class_name")" \
        "$(json_escape "$tooltip")"
}

get_ipv4_cidr() {
    ip -o -4 addr show dev "$1" scope global 2>/dev/null | awk 'NR == 1 { print $4; exit }'
}

get_essid() {
    if command -v iw >/dev/null 2>&1; then
        iw dev "$1" link 2>/dev/null | awk -F': ' '/SSID/ { print $2; exit }'
        return
    fi

    if command -v iwgetid >/dev/null 2>&1; then
        iwgetid "$1" --raw 2>/dev/null
    fi
}

get_signal_percent() {
    if ! command -v iw >/dev/null 2>&1; then
        return
    fi

    signal_dbm=$(iw dev "$1" link 2>/dev/null | awk '/signal:/ { print int($2); exit }')
    [ -n "$signal_dbm" ] || return

    signal_percent=$(( (signal_dbm + 100) * 2 ))
    [ "$signal_percent" -lt 0 ] && signal_percent=0
    [ "$signal_percent" -gt 100 ] && signal_percent=100
    printf '%s\n' "$signal_percent"
}

build_tooltip() {
    iface=$1
    address=$2

    if [ -n "$address" ]; then
        printf 'Ifname: %s | IPv4: %s' "$iface" "$address"
        return
    fi

    printf 'Ifname: %s' "$iface"
}

case "$kind" in
    wlan|lan|tether)
        ;;
    *)
        print_json "" "invalid" ""
        exit 1
        ;;
esac

case "$variant" in
    leader|detail)
        ;;
    *)
        print_json "" "invalid" ""
        exit 1
        ;;
esac

iface=$(select_iface "$kind")

if [ -z "$iface" ] || ! has_global_ip "$iface"; then
    case "$kind" in
        wlan)
            if [ "$variant" = "leader" ]; then
                print_json '󰯡 ' 'disconnected' ''
            else
                print_json '' 'disconnected detail' ''
            fi
            ;;
        tether)
            if [ "$variant" = "leader" ]; then
                print_json '' 'disconnected' ''
            else
                print_json '' 'disconnected detail' ''
            fi
            ;;
        *)
            print_json '' 'disconnected' ''
            ;;
    esac
    exit 0
fi

address=$(get_ipv4_cidr "$iface")
tooltip=$(build_tooltip "$iface" "$address")

case "$kind" in
    wlan)
        essid=$(get_essid "$iface")
        signal_percent=$(get_signal_percent "$iface")

        if [ "$variant" = "detail" ]; then
            if [ -n "$signal_percent" ]; then
                text="$address ($signal_percent%)"
            else
                text="$address"
            fi
        elif [ -n "$essid" ] && [ -n "$signal_percent" ]; then
            text="󰀂 $essid($signal_percent%)"
        elif [ -n "$essid" ]; then
            text="󰀂 $essid"
        else
            text="󰀂 $iface"
        fi

        print_json "$text" "$variant" "$tooltip"
        ;;
    tether)
        if [ "$variant" = "detail" ]; then
            text="$address"
        else
            text=''
        fi

        print_json "$text" "$variant" "$tooltip"
        ;;
    lan)
        if [ "$variant" = "detail" ]; then
            text="$address"
        else
            text='󰱔'
        fi

        print_json "$text" "$variant" "$tooltip"
        ;;
esac
