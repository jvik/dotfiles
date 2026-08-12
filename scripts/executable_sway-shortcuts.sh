#!/bin/bash
# Fuzzy-searchable overlay of every sway keybinding, built by parsing the live
# sway config at invocation time. Selecting an entry runs that binding's command
# via swaymsg, so the overlay doubles as a command palette.
#
# Descriptions are derived from the sway command itself. To override one, put a
# `#: some description` comment on the line directly above the bindsym.
#
# Usage:
#   sway-shortcuts.sh                 show the overlay
#   sway-shortcuts.sh --dump          print the parsed rows (debugging)
#   sway-shortcuts.sh --config FILE   parse FILE instead of the live config
#
# Note: no `set -e` -- wofi exits 1 when the user presses Escape, which is a
# normal path here, so exit statuses are handled explicitly instead.
set -uo pipefail

WOFI_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/wofi/shortcuts.conf"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/sway/config"
DUMP=0

die() {
    notify-send -i dialog-error "sway-shortcuts" "$1" 2>/dev/null
    echo "sway-shortcuts: $1" >&2
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dump|-n) DUMP=1; shift ;;
        --config|-c) CONFIG="${2:-}"; shift 2 ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
done

[ -r "$CONFIG" ] || CONFIG=/etc/sway/config
[ -r "$CONFIG" ] || die "no readable sway config (tried ~/.config/sway/config)"

# --- config expansion -------------------------------------------------------
# Stream the config with `include` directives resolved inline, so that `set $var`
# definitions are seen in exactly the order sway sees them.
declare -A SEEN=()

expand_config() {
    local file=$1 depth=${2:-0} real dir line target g
    ((depth > 8)) && return 0
    real=$(readlink -f -- "$file" 2>/dev/null) || return 0
    [ -f "$real" ] && [ -r "$real" ] || return 0
    [ -n "${SEEN[$real]:-}" ] && return 0
    SEEN[$real]=1
    dir=$(dirname -- "$real")

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ $line =~ ^[[:space:]]*include[[:space:]]+(.+)$ ]]; then
            target=${BASH_REMATCH[1]}
            target=${target%"${target##*[![:space:]]}"}
            target=${target//\"/}
            target=${target/#\~/$HOME}
            target=${target//\$HOME/$HOME}
            [[ $target != /* ]] && target="$dir/$target"
            # unquoted on purpose: glob expansion (nullglob makes a miss vanish)
            for g in $target; do expand_config "$g" $((depth + 1)); done
            continue
        fi
        printf '%s\n' "$line"
    done <"$real"
}
shopt -s nullglob

# --- parser -----------------------------------------------------------------
read -r -d '' AWK_PARSER <<'AWK_EOF'
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

function unquote(s) {
    if (s ~ /^".*"$/ || s ~ /^'.*'$/) return substr(s, 2, length(s) - 2)
    return s
}

# index/substr replacement: gsub() would reinterpret & and \ in the replacement,
# and sway values legitimately contain both (e.g. `&&`, `\"`).
function rep(s, from, to,   out, p) {
    if (from == "") return s
    out = ""
    while ((p = index(s, from)) > 0) {
        out = out substr(s, 1, p - 1) to
        s = substr(s, p + length(from))
    }
    return out s
}

function cnt(s, ch,   n, p) {
    n = 0
    while ((p = index(s, ch)) > 0) { n++; s = substr(s, p + 1) }
    return n
}

# Variables are kept sorted longest-name-first so that $locker cannot swallow
# the prefix of $lockman.
function add_var(n, v,   i, j) {
    for (i = 1; i <= nvar; i++) if (length(vname[i]) < length(n)) break
    for (j = nvar; j >= i; j--) { vname[j + 1] = vname[j]; vval[j + 1] = vval[j] }
    vname[i] = n; vval[i] = v; nvar++
}

function subst(s,   i) {
    for (i = 1; i <= nvar; i++) s = rep(s, vname[i], vval[i])
    return s
}

# Visible width. gawk's length()/substr() are character-based, mawk's are
# byte-based; MB is set in BEGIN and CONT holds the UTF-8 continuation bytes,
# which are skipped when counting under a byte-based awk.
function ulen(s,   n, i) {
    if (!MB) return length(s)
    n = 0
    for (i = 1; i <= length(s); i++) if (index(CONT, substr(s, i, 1)) == 0) n++
    return n
}

function upad(s, w,   n) {
    n = ulen(s)
    return (n < w) ? s sprintf("%*s", w - n, "") : s
}

function utrunc(s, w,   i, c, out, seen) {
    if (ulen(s) <= w) return s
    if (!MB) return substr(s, 1, w - 1) "…"
    out = ""; seen = 0
    for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (index(CONT, c) == 0) {
            if (seen >= w - 1) break
            seen++
        }
        out = out c
    }
    return out "…"
}

# rep() is a literal replacer, so no backslash escaping here.
# & must be replaced first, or the entities we add get double-escaped.
function esc(s) {
    s = rep(s, "&", "&amp;")
    s = rep(s, "<", "&lt;")
    return rep(s, ">", "&gt;")
}

function scase(s) { return toupper(substr(s, 1, 1)) substr(s, 2) }

function basename(p,   i) {
    i = index(p, "/")
    while (i > 0) { p = substr(p, i + 1); i = index(p, "/") }
    return p
}

function setup_keys() {
    KEY["mod4"] = "Super"; KEY["super"] = "Super"; KEY["super_l"] = "Super"
    KEY["super_r"] = "Super"; KEY["logo"] = "Super"; KEY["win"] = "Super"
    KEY["mod1"] = "Alt"; KEY["alt"] = "Alt"; KEY["alt_l"] = "Alt"; KEY["alt_r"] = "Alt"
    KEY["control"] = "Ctrl"; KEY["ctrl"] = "Ctrl"
    KEY["control_l"] = "Ctrl"; KEY["control_r"] = "Ctrl"
    KEY["shift"] = "Shift"; KEY["shift_l"] = "Shift"; KEY["shift_r"] = "Shift"
    KEY["mod3"] = "Hyper"; KEY["mod5"] = "AltGr"

    KEY["return"] = "Enter"; KEY["kp_enter"] = "Enter"; KEY["escape"] = "Esc"
    KEY["space"] = "Space"; KEY["tab"] = "Tab"; KEY["backspace"] = "Backspace"
    KEY["delete"] = "Del"; KEY["insert"] = "Ins"
    KEY["prior"] = "PgUp"; KEY["page_up"] = "PgUp"
    KEY["next"] = "PgDn"; KEY["page_down"] = "PgDn"
    KEY["print"] = "PrtSc"; KEY["menu"] = "Menu"
    KEY["left"] = "←"; KEY["down"] = "↓"; KEY["up"] = "↑"; KEY["right"] = "→"

    KEY["minus"] = "-"; KEY["equal"] = "="; KEY["period"] = "."; KEY["comma"] = ","
    KEY["slash"] = "/"; KEY["backslash"] = "\\"; KEY["semicolon"] = ";"
    KEY["apostrophe"] = "'"; KEY["grave"] = "`"; KEY["underscore"] = "_"
    KEY["bracketleft"] = "["; KEY["bracketright"] = "]"
    KEY["question"] = "?"; KEY["exclam"] = "!"; KEY["at"] = "@"
    KEY["numbersign"] = "#"; KEY["dollar"] = "$"; KEY["percent"] = "%"
    KEY["asciicircum"] = "^"; KEY["ampersand"] = "&"; KEY["asterisk"] = "*"
    KEY["parenleft"] = "("; KEY["parenright"] = ")"
    KEY["less"] = "<"; KEY["greater"] = ">"
    # a literal + would collide with the combo separator
    KEY["plus"] = "Plus"
    # Norwegian layout
    KEY["oslash"] = "Ø"; KEY["ae"] = "Æ"; KEY["aring"] = "Å"

    KEY["xf86audiomute"] = "Mute"
    KEY["xf86audiolowervolume"] = "Volume Down"
    KEY["xf86audioraisevolume"] = "Volume Up"
    KEY["xf86audiomicmute"] = "Mic Mute"
    KEY["xf86monbrightnessdown"] = "Brightness Down"
    KEY["xf86monbrightnessup"] = "Brightness Up"
    KEY["xf86audioprev"] = "Prev Track"
    KEY["xf86audioplay"] = "Play/Pause"
    KEY["xf86audionext"] = "Next Track"
    KEY["xf86display"] = "Display"

    APP["org.wezfurlong.wezterm"] = "WezTerm"
    APP["com.github.ismaelmartinez.teams_for_linux"] = "Teams"
    APP["com.slack.slack"] = "Slack"
    APP["md.obsidian.obsidian"] = "Obsidian"
    APP["it.mijorus.smile"] = "Smile"
    APP["com.bitwarden.desktop"] = "Bitwarden"
}

function xf86(k,   s, i, c, out) {
    s = substr(k, 5)
    out = ""
    for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (i > 1 && c ~ /[A-Z]/) out = out " "
        out = out c
    }
    return out
}

function map_key(k,   lk) {
    lk = tolower(k)
    if (lk in KEY) return KEY[lk]
    if (k ~ /^XF86/) return xf86(k)
    if (length(k) == 1) return toupper(k)
    return k
}

function pretty_combo(c,   n, parts, i, out) {
    n = split(c, parts, "+")
    out = ""
    for (i = 1; i <= n; i++) out = (out == "") ? map_key(parts[i]) : out "+" map_key(parts[i])
    return out
}

function app_name(id,   lid, last, i) {
    lid = tolower(id)
    if (lid in APP) return APP[lid]
    last = id
    i = index(last, ".")
    while (i > 0) { last = substr(last, i + 1); i = index(last, ".") }
    return scase(rep(last, "_", " "))
}

# ---- description engine ----

function desc_exec(c,   bin, args, i, id, rest) {
    # $lockman expands to `exec bash ...`, so a binding using it yields `exec exec ...`
    while (c ~ /^exec[ \t]+/) sub(/^exec[ \t]+/, "", c)
    c = trim(unquote(trim(c)))
    while (c ~ /^exec[ \t]+/) sub(/^exec[ \t]+/, "", c)

    if (c ~ /focus/ && index(c, "||") > 0 && index(c, "flatpak run ") > 0) {
        id = substr(c, index(c, "flatpak run ") + 12)
        sub(/[ \t"'].*$/, "", id)
        return "Focus or launch " app_name(id)
    }
    if (c ~ /^flatpak[ \t]+run[ \t]/) {
        id = c; sub(/^flatpak[ \t]+run[ \t]+/, "", id); sub(/[ \t"'].*$/, "", id)
        return "Launch " app_name(id)
    }
    if (c ~ /swaynag/ && c ~ /swaymsg exit/) return "Exit sway (confirm)"

    bin = c; sub(/[ \t].*$/, "", bin)
    args = (bin == c) ? "" : trim(substr(c, length(bin) + 1))

    if (bin ~ /^(bash|sh|zsh|python3?)$/ && args != "") return desc_exec(args)

    if (bin ~ /^wpctl$/) {
        if (c ~ /DEFAULT_AUDIO_SOURCE.*toggle/) return "Toggle microphone mute"
        if (c ~ /set-mute.*toggle/) return "Toggle mute"
        if (c ~ /5%-/) return "Volume down 5%"
        if (c ~ /5%\+/) return "Volume up 5%"
    }
    if (bin ~ /^brightnessctl$/) {
        if (c ~ /5%-/) return "Brightness down 5%"
        if (c ~ /5%\+/) return "Brightness up 5%"
    }
    if (bin ~ /^playerctl$/) {
        if (args ~ /^previous/) return "Previous track"
        if (args ~ /^next/) return "Next track"
        if (args ~ /^play-pause/) return "Play / pause"
    }

    bin = basename(bin)
    if (bin ~ /\.sh$/) {
        sub(/\.sh$/, "", bin)
        bin = scase(rep(rep(bin, "-", " "), "_", " "))
        return (args == "") ? bin : bin " " args
    }
    if (args == "" || args ~ /(^| )-/) return "Launch " scase(bin)
    return scase(bin) " " args
}

function desc_builtin(c,   m) {
    if (c == "kill") return "Close window"
    if (c == "reload") return "Reload sway config"
    if (c == "exit") return "Exit sway"
    if (c ~ /^fullscreen/) return "Toggle fullscreen"
    if (c ~ /^focus (left|right|up|down)$/) { m = c; sub(/^focus /, "", m); return "Focus " m }
    if (c == "focus parent") return "Focus parent container"
    if (c == "focus child") return "Focus child container"
    if (c == "focus mode_toggle") return "Switch focus tiling ↔ floating"
    if (c ~ /^move (left|right|up|down)$/) { m = c; sub(/^move /, "", m); return "Move window " m }
    if (c ~ /^move container to workspace number /) {
        m = c; sub(/^move container to workspace number /, "", m); return "Move window to workspace " m
    }
    if (c ~ /^move workspace to output /) {
        m = c; sub(/^move workspace to output /, "", m); return "Move workspace to output " m
    }
    if (c ~ /^move scratchpad/) return "Move window to scratchpad"
    if (c ~ /^scratchpad show/) return "Show scratchpad window"
    if (c ~ /^workspace number /) { m = c; sub(/^workspace number /, "", m); return "Go to workspace " m }
    if (c ~ /^workspace back_and_forth/) return "Back to previous workspace"
    if (c == "splith") return "Split horizontally"
    if (c == "splitv") return "Split vertically"
    if (c ~ /^layout /) { m = c; sub(/^layout /, "", m); return "Layout: " m }
    if (c ~ /^floating toggle/) return "Toggle floating"
    if (c ~ /^sticky toggle/) return "Toggle sticky (pin to all workspaces)"
    if (c ~ /^resize (shrink|grow) (width|height)/) {
        split(c, m2, " ")
        return scase(m2[2]) " " m2[3]
    }
    return ""
}

function describe(c,   m, first, ci, crit, restc, d) {
    c = trim(c)
    # inside a mode block every binding leaves the mode first -- pure noise
    sub(/^mode[ \t]+"?default"?[ \t]*;[ \t]*/, "", c)
    c = trim(c)

    # a `mode <name>` segment is the most informative thing on the line
    if (match(c, /(^|;[ \t]*)mode[ \t]+[^;]+$/)) {
        m = substr(c, RSTART, RLENGTH)
        sub(/^;[ \t]*/, "", m)
        sub(/^mode[ \t]+/, "", m)
        m = unquote(trim(m))
        if (m == "default") return "Leave mode"
        first = m; sub(/[ \t].*$/, "", first)
        return "Enter " first " mode"
    }

    if (c ~ /^\[/) {
        ci = index(c, "]")
        if (ci > 0) {
            crit = substr(c, 2, ci - 2)
            restc = trim(substr(c, ci + 1))
            if (crit ~ /urgent/ && restc ~ /^focus/) return "Focus urgent window"
            d = describe(restc)
            return d " [" crit "]"
        }
    }

    d = desc_builtin(c)
    if (d != "") return d

    if (c ~ /^exec([ \t]|$)/) return desc_exec(c)

    # chained command: describe the first segment only
    if (index(c, ",") > 0 || index(c, ";") > 0) {
        m = c
        sub(/[,;].*$/, "", m)
        m = trim(m)
        if (m != c && m != "") {
            d = desc_builtin(m)
            if (d != "") return d
            if (m ~ /^exec([ \t]|$)/) return desc_exec(m)
        }
    }
    return c
}

# ---- row assembly ----

function emit(sect, mode, combo, cmd, locked, override,   d, k) {
    d = (override != "") ? override : describe(cmd)
    if (locked) d = d " · locked"
    k = sect SUBSEP mode SUBSEP d SUBSEP cmd SUBSEP locked
    if (!(k in gseen)) {
        gseen[k] = 1
        gorder[++ng] = k
        gsect[k] = sect; gmode[k] = mode; gdesc[k] = d; gcmd[k] = cmd
        gcombos[k] = combo; gn[k] = 1
    } else if (gn[k] < 4) {
        gcombos[k] = gcombos[k] SUBSEP combo
        gn[k]++
    } else if (gn[k] == 4) {
        gcombos[k] = gcombos[k] SUBSEP "…"
        gn[k]++
    }
}

function join_combos(blob,   n, a, i, pfx, p, rest, out) {
    n = split(blob, a, SUBSEP)
    if (n == 1) return a[1]
    pfx = a[1]
    p = 0
    for (i = length(pfx); i >= 1; i--) if (substr(pfx, i, 1) == "+") { p = i; break }
    pfx = (p > 0) ? substr(a[1], 1, p) : ""
    for (i = 1; i <= n; i++) {
        if (index(a[i], pfx) != 1) return join_plain(blob)
        rest = substr(a[i], length(pfx) + 1)
        if (index(rest, "+") > 0 || rest == "") return join_plain(blob)
    }
    out = ""
    for (i = 1; i <= n; i++) {
        rest = substr(a[i], length(pfx) + 1)
        out = (out == "") ? rest : out "/" rest
    }
    return pfx out
}

function join_plain(blob,   n, a, i, out) {
    n = split(blob, a, SUBSEP)
    out = ""
    for (i = 1; i <= n; i++) out = (out == "") ? a[i] : out " / " a[i]
    return out
}

BEGIN {
    MB = (length("←") > 1)
    if (MB) for (b = 128; b <= 191; b++) CONT = CONT sprintf("%c", b)
    setup_keys()
    if (KW == 0) KW = 26
    if (DW == 0) DW = 46
    if (CW == 0) CW = 56
    sect = "Other"
    curmode = ""
    depth = 0
    pending = ""
}

{
    line = $0
    gsub(/\t/, " ", line)        # tab is our output field separator
    line = trim(line)

    if (line == "") { pending = ""; next }
    if (line ~ /^#:/) { pending = trim(substr(line, 3)); next }
    if (line ~ /^###/) { next }
    if (line ~ /^##/) { sect = trim(substr(line, 3)); pending = ""; next }
    if (line ~ /^#/) { next }

    if (line ~ /^set[ \t]+\$/) {
        vn = line; sub(/^set[ \t]+/, "", vn)
        vv = vn
        sub(/[ \t].*$/, "", vn)
        vv = (vv == vn) ? "" : trim(substr(vv, length(vn) + 1))
        add_var(vn, subst(vv))
        pending = ""
        next
    }

    line = subst(line)
    opens = cnt(line, "{")
    closes = cnt(line, "}")

    if (line ~ /^mode[ \t]/ && opens > 0) {
        mn = line
        sub(/^mode[ \t]+/, "", mn)
        sub(/[ \t]*\{[ \t]*$/, "", mn)
        curmode = unquote(trim(mn))
        depth += opens - closes
        pending = ""
        next
    }

    depth += opens - closes
    if (depth <= 0) { depth = 0; if (line ~ /\}/) curmode = "" }

    if (line ~ /^bind(sym|code)[ \t]/) {
        kind = (line ~ /^bindcode/) ? "code:" : ""
        rest = line
        sub(/^bind(sym|code)[ \t]+/, "", rest)

        locked = 0
        while (rest ~ /^--/) {
            f = rest; sub(/[ \t].*$/, "", f)
            if (f ~ /^--locked/) locked = 1
            if (!sub(/^[^ \t]+[ \t]+/, "", rest)) break
        }

        combo = rest; sub(/[ \t].*$/, "", combo)
        cmd = trim((combo == rest) ? "" : substr(rest, length(combo) + 1))
        pc = kind pretty_combo(combo)

        # remember which top-level binding enters each mode, to prefix its rows
        if (curmode == "" && match(cmd, /(^|;[ \t]*)mode[ \t]+[^;]+$/)) {
            tm = substr(cmd, RSTART, RLENGTH)
            sub(/^;[ \t]*/, "", tm)
            sub(/^mode[ \t]+/, "", tm)
            tm = unquote(trim(tm))
            if (tm != "default" && !(tm in trigger)) trigger[tm] = pc
        }

        emit(sect, curmode, pc, cmd, locked, pending)
        pending = ""
        next
    }

    pending = ""
}

END {
    lastsect = ""
    for (i = 1; i <= ng; i++) {
        k = gorder[i]
        if (gsect[k] != lastsect) {
            lastsect = gsect[k]
            bar = ""
            for (j = ulen(lastsect); j < KW + DW + CW - 4; j++) bar = bar "─"
            printf "<span weight=\"bold\" alpha=\"60%%\">── %s %s</span>\t\n", esc(lastsect), bar
        }
        keys = gcombos[k]
        keys = join_combos(keys)
        if (gmode[k] != "" && (gmode[k] in trigger)) keys = trigger[gmode[k]] " → " keys
        printf "<b>%s</b>  %s  <span alpha=\"45%%\">%s</span>\t%s\n", \
            esc(upad(utrunc(keys, KW), KW)), \
            esc(upad(utrunc(gdesc[k], DW), DW)), \
            esc(utrunc(gcmd[k], CW)), \
            gcmd[k]
    }
}
AWK_EOF

mapfile -t rows < <(expand_config "$CONFIG" | awk "$AWK_PARSER")

[ "${#rows[@]}" -gt 0 ] || die "no keybindings found in $CONFIG"

if [ "$DUMP" -eq 1 ]; then
    printf '%s\n' "${rows[@]}"
    exit 0
fi

command -v wofi >/dev/null 2>&1 || die "wofi is not installed"

lines=()
cmds=()
for row in "${rows[@]}"; do
    lines+=("${row%%$'\t'*}")
    cmds+=("${row#*$'\t'}")
done

sel=$(printf '%s\n' "${lines[@]}" |
    wofi --conf "$WOFI_CONF" --dmenu \
        --prompt 'Shortcut' \
        --width 1200 --height 720 \
        --cache-file /dev/null \
        --no-custom-entry) || exit 0

[ -n "$sel" ] || exit 0
case "$sel" in '' | *[!0-9]*) exit 0 ;; esac

# dmenu-print_line_num is 0-based (wofi modes/dmenu.c: `line_num = 0` with a
# post-increment when the action string is built)
[ "$sel" -lt "${#cmds[@]}" ] || exit 0

cmd=${cmds[$sel]}
[ -n "$cmd" ] || exit 0   # section header row

if ! out=$(swaymsg -- "$cmd" 2>&1) || [[ $out == *'"success": false'* ]]; then
    notify-send -i dialog-error "Shortcut failed" "$cmd"$'\n'"$out" 2>/dev/null
fi
