function fish_right_prompt
    # Colors
    set -l normal (set_color normal)
    set -l brblack (set_color brblack)
    set -l cyan (set_color cyan)
    
    # Show command duration for commands that take longer than 2 seconds
    set -l cmd_duration_info ""
    if test $CMD_DURATION -gt 2000
        set -l duration_seconds (math $CMD_DURATION / 1000)
        set cmd_duration_info $brblack"took "$cyan(printf "%.1fs" $duration_seconds)" "
    end
    
    # Show current time
    set -l time_info $brblack(date "+%H:%M:%S")
    
    echo -n $cmd_duration_info$time_info$normal
end
