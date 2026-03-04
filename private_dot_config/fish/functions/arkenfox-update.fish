function arkenfox-update --description "Update arkenfox user.js for Firefox"
    set updater ~/.config/mozilla/firefox/main/updater.sh
    if not test -f "$updater"
        echo "updater.sh not found, downloading..."
        curl -fsSL https://raw.githubusercontent.com/arkenfox/user.js/master/updater.sh -o $updater
        chmod +x $updater
    end
    $updater
end
