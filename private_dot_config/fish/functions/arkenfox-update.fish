function arkenfox-update --description "Update arkenfox user.js for Firefox"
    set source_dir ~/.config/mozilla/firefox/main
    set updater $source_dir/updater.sh

    if not test -f $updater
        echo "updater.sh not found, downloading..."
        curl -fsSL https://raw.githubusercontent.com/arkenfox/user.js/master/updater.sh -o $updater
        chmod +x $updater
    end

    set installs_ini ~/.mozilla/firefox/installs.ini
    if not test -f $installs_ini
        echo "Firefox installs.ini not found at $installs_ini"
        return 1
    end

    # Pick the most recently used profile (installs.ini can have stale entries from old installs)
    set best_profile ""
    set best_mtime 0
    for p in (awk -F= '/^Default=/{print ENVIRON["HOME"] "/.mozilla/firefox/" $2}' $installs_ini)
        if not test -d $p
            continue
        end
        set mtime (stat -c %Y $p/prefs.js 2>/dev/null; or echo 0)
        if test $mtime -gt $best_mtime
            set best_mtime $mtime
            set best_profile $p
        end
    end

    if test -z "$best_profile"
        echo "No active Firefox profile found"
        return 1
    end

    echo "Deploying arkenfox to: $best_profile"
    cp $source_dir/user-overrides.js $best_profile/user-overrides.js
    $updater -p $best_profile
end
