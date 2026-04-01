function _fzf_search_directory --description "Search the current directory. Replace the current token with the selected file paths."
    # Directly use fd binary to avoid output buffering delay caused by a fd alias, if any.
    # Debian-based distros install fd as fdfind and the fd package is something else, so
    # check for fdfind first. Fall back to "fd" for a clear error message.
    set -f fd_cmd (command -v fdfind || command -v fd  || echo "fd")
    set -f --append fd_cmd $fzf_fd_opts

    # Don't use --accept-nth or {2} — fzf <=0.70 strips leading whitespace from fields.
    # Extract the original path from {} by splitting on tab instead.
    set -f fzf_arguments --multi --delimiter='\t' --with-nth=1 $fzf_directory_opts
    set -f token (commandline --current-token)
    # expand any variables or leading tilde (~) in the token
    set -f expanded_token (eval echo -- $token)
    # unescape token because it's already quoted so backslashes will mess up the path
    set -f unescaped_exp_token (string unescape -- $expanded_token)

    # If the current token is a directory and has a trailing slash,
    # then use it as fd's base directory.
    if string match --quiet -- "*/" $unescaped_exp_token && test -d "$unescaped_exp_token"
        set --append fd_cmd --base-directory=$unescaped_exp_token
        set --prepend fzf_arguments --prompt="  " --preview="set -l _o (string split \\t -- {}); _fzf_preview_file $expanded_token\$_o[-1]"
        set -f prefix $unescaped_exp_token
    else
        set --prepend fzf_arguments --prompt="  " --query="$unescaped_exp_token" --preview='set -l _o (string split \t -- {}); _fzf_preview_file $_o[-1]'
        set -f prefix ""
    end

    set -f fzf_output (
        $fd_cmd 2>/dev/null | _fzf_shorten_path | _fzf_wrapper $fzf_arguments
    )
    if test $status -eq 0
        set -f file_paths_selected
        for line in $fzf_output
            set --append file_paths_selected $prefix(string split \t -- $line)[-1]
        end
        commandline --current-token --replace -- (string escape -- $file_paths_selected | string join ' ')
    end

    commandline --function repaint
end
