function arkenfox-update --description "Update arkenfox user.js for Firefox"
    set source_dir ~/.config/mozilla/firefox/main
    set updater $source_dir/updater.sh

    if not test -d $source_dir
        echo "Firefox profile not found at $source_dir"
        return 1
    end

    if not test -f $updater
        echo "updater.sh not found, downloading..."
        curl -fsSL https://raw.githubusercontent.com/arkenfox/user.js/master/updater.sh -o $updater
        chmod +x $updater
    end

    # $source_dir is the profile itself, so user-overrides.js is already in place
    # and updater.sh picks it up on its own. -d keeps the pinned updater.sh from
    # self-updating to master behind the checksum in firefox-arkenfox.yml.
    echo "Deploying arkenfox to: $source_dir"
    $updater -d -s -p $source_dir
end
