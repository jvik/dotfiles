function bw-unlock --description "Unlock Bitwarden and export BW_SESSION for this shell"
    # Prefer a native bw on PATH (what scripts/tools like ansible's bitwarden
    # lookup plugin actually invoke) so BW_SESSION is valid for them too;
    # fall back to the flatpak app's bundled CLI if no native bw exists.
    set -l bw
    if command -q bw
        set bw bw
    else if flatpak list 2>/dev/null | grep -q com.bitwarden.desktop
        set bw flatpak run --command=bw com.bitwarden.desktop
    else
        echo "Bitwarden CLI not found (no native bw, no com.bitwarden.desktop flatpak)." >&2
        return 1
    end

    # Already unlocked and session still valid? Reuse it.
    if set -q BW_SESSION; and $bw unlock --check --session $BW_SESSION >/dev/null 2>&1
        echo "Bitwarden already unlocked (BW_SESSION set)."
        return 0
    end

    # Must be logged in first.
    set -l login_status ($bw login --check 2>&1)
    if string match -q "*not logged in*" -- $login_status
        echo "Not logged in to Bitwarden. Run: $bw login" >&2
        return 1
    end

    # Unlock; --raw prints only the session key.
    set -l token ($bw unlock --raw)
    or return 1

    if test -z "$token"
        echo "Bitwarden unlock returned empty session." >&2
        return 1
    end

    set -gx BW_SESSION $token
    echo "BW_SESSION exported for this shell (via $bw)."
end
