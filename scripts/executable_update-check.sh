#!/bin/bash
# Check for pending dnf/apt + Flatpak updates and notify if any are found.
# Designed to run daily via a systemd timer, unattended.
#
# Deliberately queries dnf/apt/flatpak directly rather than shelling out to
# topgrade: none of these checks need root, so this stays fast and silent enough
# to run from a timer, whereas `topgrade --dry-run` wants a sudo ticket.
# Applying updates is topgrade's job (see ~/.config/topgrade.toml).

SUMMARY_DIR="$HOME/.cache/update-check"
SUMMARY="$SUMMARY_DIR/summary.json"
mkdir -p "$SUMMARY_DIR"

dnf_count=0
apt_count=0

# shellcheck disable=SC1091
. /etc/os-release
case "$ID" in
    fedora)
        dnf_count=$(dnf check-update 2>/dev/null | grep -c '^\S')
        ;;
    ubuntu|debian)
        apt_count=$(apt list --upgradable 2>/dev/null | grep -vc '^Listing')
        ;;
esac

# `flatpak remote-ls --updates` compares the remote commit against the ref's
# local commit. For an OCI remote -- Fedora's registry.fedoraproject.org is one
# -- flatpak rewrites that commit on deploy and keeps the remote's own hash as
# Alt-id, so every ref from such a remote looks permanently out of date while
# `flatpak update` (which checks Alt-id) correctly finds nothing to do. Count a
# ref only when the remote commit matches neither id. The commit column is
# truncated to 12 characters and `flatpak info` prints the full hash, so the
# substring match below is really a prefix match.
count_flatpak_updates() {
    local count=0 ref commit ids
    while IFS=$'\t' read -r ref commit; do
        [ -n "$ref" ] || continue
        ids=$(flatpak info "$ref" 2>/dev/null | awk '/^ *(Commit|Alt-id):/ { print $2 }')
        case "$ids" in
            *"$commit"*) ;; # already deployed
            *) count=$((count + 1)) ;;
        esac
    done < <(flatpak remote-ls --updates --columns=ref,commit 2>/dev/null)
    printf '%s\n' "$count"
}

flatpak_count=$(count_flatpak_updates)

checked_at=$(date -Iseconds)
jq -n --argjson dnf "$dnf_count" --argjson apt "$apt_count" --argjson flatpak "$flatpak_count" --arg checked_at "$checked_at" \
    '{dnf: $dnf, apt: $apt, flatpak: $flatpak, checked_at: $checked_at}' > "$SUMMARY"

# Plain `if`, not `(( total > 0 )) && notify-send ...`: as the script's last
# command that compound exits 1 when nothing is pending, which systemd reports
# as a failed update-check.service.
total=$((dnf_count + apt_count + flatpak_count))
if (( total > 0 )); then
    notify-send -i software-update-available \
        "Updates available" "$total package(s) ready to update"
fi
