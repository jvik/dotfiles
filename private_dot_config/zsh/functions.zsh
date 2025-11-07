function pasta() {
  if hash pbpaste 2>/dev/null; then
    pbpaste
  elif hash xclip 2>/dev/null; then
    xclip -selection clipboard -o
  elif [[ -e /tmp/clipboard ]]; then
    cat /tmp/clipboard
  else
    echo ''
  fi
}

function copy() {
  if hash pbcopy 2>/dev/null; then
    pbcopy
  elif hash xclip 2>/dev/null; then
    xclip -selection clipboard
  elif hash putclip 2>/dev/null; then
    putclip
  else
    rm -f /tmp/clipboard 2>/dev/null
    if [[ $# -eq 0 ]]; then
      cat >/tmp/clipboard
    else
      cat "$1" >/tmp/clipboard
    fi
  fi
}

function ghfuzzyclone() {
        gh repo list kystverket | fzf --preview "echo {}" | awk '{print $1}' | xargs gh repo clone
}

function t() {
  {
    exec </dev/tty
    exec <&1
    local session
    session=$(sesh list -t -c | fzf --height 40% --reverse --border-label ' sesh ' --border --prompt '⚡  ')
    [[ -z "$session" ]] && return
    sesh connect $session
  }
}
