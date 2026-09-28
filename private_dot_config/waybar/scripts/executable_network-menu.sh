#!/usr/bin/env sh

kind=$1

case "$kind" in
    lan|usb)
        profile_type=802-3-ethernet
        ;;
    wlan)
        profile_type=802-11-wireless
        ;;
    *)
        printf 'usage: %s <lan|usb|wlan>\n' "$0" >&2
        exit 1
        ;;
esac

notify() {
    notify-send -a network "$@"
}

iface=$("$HOME/.config/waybar/scripts/network-status.sh" "$kind" iface)

if [ -z "$iface" ]; then
    notify "No $kind interface found"
    exit 0
fi

# nmcli -g escapes ':' in values and joins multiple values with ' | '.
device_field() {
    nmcli -g "$1" device show "$iface" 2>/dev/null | sed 's/\\:/:/g'
}

split_values() {
    printf '%s\n' "$1" | tr '|' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$'
}

state=$(device_field GENERAL.STATE)
connection=$(device_field GENERAL.CONNECTION)
mac=$(device_field GENERAL.HWADDR)
addresses=$(device_field IP4.ADDRESS)
gateway=$(device_field IP4.GATEWAY)
dns=$(device_field IP4.DNS)
speed=$(cat "/sys/class/net/$iface/speed" 2>/dev/null)

list_profiles() {
    nmcli -g NAME,TYPE connection show 2>/dev/null | while IFS= read -r line; do
        [ "${line##*:}" = "$profile_type" ] || continue
        name=$(printf '%s' "${line%:*}" | sed 's/\\:/:/g')
        [ "$name" = "$connection" ] && continue
        printf '%s\n' "$name"
    done
}

build_menu() {
    split_values "$addresses" | while IFS= read -r value; do
        printf '󰩟 IPv4  %s\n' "$value"
    done
    [ -n "$gateway" ] && printf '󰑩 Gateway  %s\n' "$gateway"
    split_values "$dns" | while IFS= read -r value; do
        printf '󰇖 DNS  %s\n' "$value"
    done
    [ -n "$mac" ] && printf '󰈀 MAC  %s\n' "$mac"
    case "$speed" in
        ''|-1) ;;
        *) printf '󰓅 Speed  %s Mb/s\n' "$speed" ;;
    esac
    [ -n "$connection" ] && printf '󰌘 Profile  %s\n' "$connection"

    # GENERAL.STATE is "<code> (<name>)": 10 unmanaged, 20 unavailable (no
    # carrier), 30 disconnected, 40-90 activating, 100 connected.
    case "$state" in
        10\ *)
            printf '󰌘 Enable\n'
            ;;
        20\ *)
            if [ "$kind" = wlan ]; then
                printf '󰌙 Status  Unavailable\n'
            else
                printf '󰌙 Status  No cable\n'
            fi
            ;;
        30\ *)
            printf '󰌘 Connect\n'
            ;;
        100\ *)
            printf '󰑓 Reconnect\n'
            printf '󰌙 Disconnect\n'
            ;;
        *)
            printf '󰌙 Disconnect\n'
            ;;
    esac
    case "$state" in
        30\ *|100\ *)
            list_profiles | while IFS= read -r name; do
                printf '󰒍 Use profile: %s\n' "$name"
            done
            ;;
    esac
    case "$state" in
        10\ *) ;;
        *) printf '󰜺 Disable\n' ;;
    esac
    printf ' Edit connections\n'
}

run_nmcli() {
    label=$1
    shift

    if output=$(nmcli "$@" 2>&1); then
        notify "$label" "$iface"
    else
        notify -u critical "$label failed" "$output"
    fi
}

choice=$(build_menu | fuzzel --dmenu --prompt "$kind ($iface)> ")
[ -n "$choice" ] || exit 0

case "$choice" in
    '󰑓 Reconnect')
        # reapply keeps the link up; fall back to a full reconnect if it refuses.
        if nmcli device reapply "$iface" >/dev/null 2>&1; then
            notify "Reconnected" "$iface"
        else
            run_nmcli "Reconnected" device connect "$iface"
        fi
        ;;
    '󰌙 Disconnect')
        run_nmcli "Disconnected" device disconnect "$iface"
        ;;
    '󰌘 Connect')
        run_nmcli "Connected" device connect "$iface"
        ;;
    # Unmanaged means NetworkManager ignores the device entirely, including
    # autoconnect when a cable is plugged in. Resets on reboot.
    '󰜺 Disable')
        run_nmcli "Disabled" device set "$iface" managed no
        ;;
    '󰌘 Enable')
        run_nmcli "Enabled" device set "$iface" managed yes
        ;;
    '󰒍 Use profile: '*)
        name=${choice#'󰒍 Use profile: '}
        run_nmcli "Activated $name" connection up "$name" ifname "$iface"
        ;;
    ' Edit connections')
        nm-connection-editor >/dev/null 2>&1 &
        ;;
    '󰌙 Status  '*)
        ;;
    *'  '*)
        value=${choice#*  }
        printf '%s' "$value" | wl-copy
        notify "Copied to clipboard" "$value"
        ;;
esac
