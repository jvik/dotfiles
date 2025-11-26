function fish_prompt
    # Save the last command status
    set -l last_status $status
    
    # Colors
    set -l normal (set_color normal)
    set -l cyan (set_color cyan)
    set -l blue (set_color blue)
    set -l green (set_color green)
    set -l yellow (set_color yellow)
    set -l red (set_color red)
    set -l magenta (set_color magenta)
    set -l brblack (set_color brblack)
    
    # User and host
    set -l user_host $cyan(whoami)$brblack@$blue(prompt_hostname)
    
    # Current directory
    set -l pwd_display $yellow(prompt_pwd)
    
    # Git status
    set -l git_info ""
    if git rev-parse --git-dir >/dev/null 2>&1
        set -l branch (git branch --show-current 2>/dev/null; or git rev-parse --short HEAD 2>/dev/null)
        set -l git_dirty ""
        
        # Check if working directory is dirty
        if not git diff --quiet 2>/dev/null; or not git diff --cached --quiet 2>/dev/null
            set git_dirty $red"*"
        end
        
        set git_info " "$brblack"on "$magenta"git:("$green$branch$git_dirty$magenta")"
    end
    
    # Kubernetes context (if kubectl is available)
    set -l k8s_info ""
    if type -q kubectl
        set -l k8s_ctx (kubectl config current-context 2>/dev/null)
        if test -n "$k8s_ctx"
            set k8s_info " "$brblack"k8s:"$cyan$k8s_ctx
        end
    end
    
    # Vi mode indicator
    set -l mode_indicator ""
    if test "$fish_key_bindings" = "fish_vi_key_bindings"
        switch $fish_bind_mode
            case default
                set mode_indicator $green"[N]"
            case insert
                set mode_indicator $blue"[I]"
            case replace_one
                set mode_indicator $yellow"[R]"
            case visual
                set mode_indicator $magenta"[V]"
        end
        set mode_indicator " "$mode_indicator
    end
    
    # Status indicator
    set -l status_indicator ""
    if test $last_status -ne 0
        set status_indicator " "$red"✗ "$last_status
    end
    
    # Build prompt
    echo -n $user_host" "$pwd_display$git_info$k8s_info$mode_indicator$status_indicator
    echo -n $normal
    echo -n \n
    
    # Prompt symbol
    if test $last_status -eq 0
        echo -n $green"❯ "$normal
    else
        echo -n $red"❯ "$normal
    end
end
