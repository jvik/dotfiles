# Fish abbreviations (similar to ZSH aliases that expand)

# Navigation
abbr -a .. 'cd ..'
abbr -a 2.. 'cd ../..'
abbr -a 3.. 'cd ../../..'
abbr -a 4.. 'cd ../../../..'
abbr -a 5.. 'cd ../../../../..'
abbr -a ,, 'cd ..'
abbr -a cd.. 'cd ..'

# Common typos
abbr -a mdkir mkdir
abbr -a dc cd
abbr -a sl ls
abbr -a sudp sudo

# Quick exit
abbr -a q exit
abbr -a :q exit

# Reload Fish config
abbr -a reload-fish 'source $HOME/.config/fish/config.fish'

# Eza (modern ls replacement)
abbr -a l 'eza -l --icons --git -a'
abbr -a lt 'eza --tree --level=2 --long --icons --git'
abbr -a ltree 'eza --tree --level=2 --icons --git'

# Kubectl abbreviations
abbr -a k kubectl
abbr -a ka 'kubectl apply -f'
abbr -a kg 'kubectl get'
abbr -a kd 'kubectl describe'
abbr -a kdel 'kubectl delete'
abbr -a kl 'kubectl logs -f'
abbr -a kgpo 'kubectl get pod'
abbr -a kgd 'kubectl get deployments'
abbr -a kc kubectx
abbr -a kns kubens
abbr -a ke 'kubectl exec -it'
abbr -a kcns 'kubectl config set-context --current --namespace'

# Tmux
abbr -a tmuxa 'tmux attach || tmux new-session'

# I3/Sway config
abbr -a i3config 'nvim ~/.config/i3/config'

# Audio
abbr -a audio alsamixer

# Bitwarden
abbr -a bw 'flatpak run --command=bw com.bitwarden.desktop'

# Git project root shortcuts
abbr cg "cd (git rev-parse --show-toplevel)"
abbr cgw "cd (git rev-parse --show-toplevel)/.github/workflows"
abbr cte "cd (git rev-parse --show-toplevel)/terraform"
abbr che "cd (git rev-parse --show-toplevel)/helmfile.d"
abbr cre "cd (git rev-parse --show-toplevel)/_rendered"