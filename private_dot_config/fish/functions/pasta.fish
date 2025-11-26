# Paste from clipboard
function pasta -d "Paste content from clipboard"
    if type -q pbpaste
        pbpaste
    else if type -q xclip
        xclip -selection clipboard -o
    else if test -e /tmp/clipboard
        cat /tmp/clipboard
    else
        echo ''
    end
end
