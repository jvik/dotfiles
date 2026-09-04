# Fuzzy find every abbreviation, alias and custom function, then put the chosen
# name on the command line so it expands on <space>. The terminal counterpart to
# $mod+? in sway (scripts/sway-shortcuts.sh).
function ab --description 'Fuzzy find abbreviations, aliases and functions'
    argparse n/dump h/help -- $argv
    or return 1

    if set -q _flag_help
        echo "ab [-n|--dump] [query]"
        echo
        echo "  Fuzzy find abbreviations, aliases and custom functions."
        echo "  Selecting an entry puts its name on the command line."
        echo
        echo "  -n, --dump    print the parsed rows instead of opening the picker"
        return 0
    end

    set -l rows (_ab_rows)

    if set -q _flag_dump
        printf '%s\n' $rows
        return 0
    end

    if not type -q fzf
        echo "ab: fzf is not installed" >&2
        return 1
    end

    # Width of the name column, so the value column lines up.
    set -l width 0
    for row in $rows
        set -l len (string length -- (string split -f2 \t -- $row))
        test $len -gt $width
        and set width $len
    end
    test $width -gt 20
    and set width 20

    # display \t name \t value -- fzf shows field 1, previews field 3,
    # and we insert field 2.
    set -l lines
    for row in $rows
        set -l parts (string split -f1,2,3 \t -- $row)
        set -l kindcol (string pad --right --width 5 -- $parts[1])
        set -l namecol (string pad --right --width $width -- $parts[2])
        set -a lines (string join \t "$kindcol $namecol  $parts[3]" $parts[2] $parts[3])
    end

    set -l picked (printf '%s\n' $lines \
        | fzf --delimiter=\t --with-nth=1 \
            --height 60% --reverse --border --border-label ' abbreviations ' \
            --prompt 'ab  ' \
            --preview 'echo {3}' --preview-window 'down,3,wrap' \
            --query "$argv" \
        | string split -f2 \t)

    test -n "$picked"
    or return 0

    if status is-interactive
        commandline -r -- $picked
    else
        echo $picked
    end
end

# Emit "kind<tab>name<tab>value" for every abbreviation, alias and custom
# function. Everything is read at invocation time, so there is no list to keep
# in sync.
function _ab_rows --description 'Collect abbreviation, alias and function rows for ab'
    # `abbr --show` and `alias` both print valid fish source, so one parser
    # handles both. Unescape only the value -- unescaping the whole line would
    # mangle the separators.
    for line in (abbr --show)
        set -l m (string match -r '^abbr\s.*?\s--\s(\S+)\s(.*)$' -- $line)
        test (count $m) -eq 3
        or continue
        printf 'abbr\t%s\t%s\n' $m[2] (string unescape --style=script -- $m[3])
    end

    # Files owned by fisher plugins, so their helpers stay out of the list.
    # Fisher records them in universal variables, with $HOME written as "~".
    set -l plugin_files
    for var in (set --names | string match -r '^_fisher_.+_files$')
        for file in $$var
            set -a plugin_files (string replace -r '^~' $HOME -- $file)
        end
    end

    # An autoloadable file only advertises the function named after it, so touch
    # each of ours first -- that loads the file and reveals any extra function
    # it defines (krepo-update lives in krepo.fish).
    for file in $__fish_config_dir/functions/*.fish
        functions --query (path basename (path change-extension '' $file))
    end

    # Aliases and functions come out of one pass -- an alias is just a function
    # that fish gave a description of the form "alias name=value" -- but they
    # are buffered so each kind prints as its own block.
    set -l aliases
    set -l fns

    for name in (functions --names)
        string match -q -- '_*' $name
        and continue
        string match -q 'fish_*' -- $name
        and continue

        # 1: definition file, 2: autoloaded, 3: line, 4: scope, 5: description
        set -l info (functions --details --verbose $name)
        test (count $info) -eq 5
        or continue
        test -n "$info[5]"
        or continue

        # Read the alias out of the description rather than asking `alias`,
        # which silently skips any alias whose value contains a single quote
        # (its listing only matches single-quoted descriptions).
        set -l m (string match -r '^alias\s[^=]+=(.*)$' -- $info[5])
        if test (count $m) -eq 2
            set -a aliases (printf 'alias\t%s\t%s' $name $m[2])
            continue
        end

        # Only our own functions: this also excludes fish's shipped ones (ls,
        # help, math, seq, ...), which have descriptions of their own.
        string match -q -- "$__fish_config_dir/functions/*" $info[1]
        or continue
        contains -- $info[1] $plugin_files
        and continue

        set -a fns (printf 'fn\t%s\t%s' $name $info[5])
    end

    for row in $aliases $fns
        echo $row
    end
end
