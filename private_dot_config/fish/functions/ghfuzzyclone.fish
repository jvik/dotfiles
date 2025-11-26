# Fuzzy clone GitHub repository
function ghfuzzyclone -d "Fuzzy search and clone a GitHub repository"
    gh repo list kystverket | fzf --preview "echo {}" | awk '{print $1}' | xargs gh repo clone
end
