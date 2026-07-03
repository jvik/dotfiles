function bw-unlock --description "Unlock Bitwarden and export BW_SESSION for this shell"
    set -l bw flatpak run --command=bw com.bitwarden.desktop

    # Already unlocked and session still valid? Reuse it.
    if set -q BW_SESSION; and $bw unlock --check --session $BW_SESSION >/dev/null 2>&1
        echo "Bitwarden already unlocked (BW_SESSION set)."
        return 0
    end

    # Must be logged in first.
    set -l login_status ($bw login --check 2>&1)
    if string match -q "*not logged in*" -- $login_status
        echo "Not logged in to Bitwarden. Run: bw login" >&2
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
    echo "BW_SESSION exported for this shell."
end
