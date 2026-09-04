# Fuzzy clone GitHub repository
function ghfuzzyclone -d "Fuzzy search and clone a GitHub repository"
    if not set -q gh_org
        echo "gh_org not set. Add 'set -gx gh_org <org>' to ~/.config/fish/local.fish" >&2
        return 1
    end

    gh repo list $gh_org | fzf --preview "echo {}" | awk '{print $1}' | xargs gh repo clone
end
