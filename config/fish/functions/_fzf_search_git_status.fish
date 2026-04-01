function _fzf_search_git_status --description "Search the output of git status. Replace the current token with the selected file paths."
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo '_fzf_search_git_status: Not in a git repository.' >&2
    else
        # Work around fzf <=0.70 bug where {2} strips leading whitespace from fields.
        # Extract the original line from {} by splitting on tab instead of using {2}.
        set -f preview_cmd 'set -l _o (string split \t -- {}); echo; _fzf_preview_changed_file $_o[-1]'
        if set --query fzf_diff_highlighter
            set preview_cmd "$preview_cmd | $fzf_diff_highlighter"
        end

        set -f selected_paths (
            git status --short |
            _fzf_shorten_path 3 |
            _fzf_wrapper --ansi \
                --multi \
                --prompt="±  " \
                --query=(commandline --current-token) \
                --preview=$preview_cmd \
                --delimiter='\t' \
                --with-nth=1 \
                $fzf_git_status_opts
        )
        if test $status -eq 0
            # git status --short automatically escapes the paths of most files for us so not going to bother trying to handle
            # the few edges cases of weird file names that should be extremely rare (e.g. "this;needs;escaping")
            set -f cleaned_paths

            for path in $selected_paths
                # Extract original git status line from after the tab
                set -l original (string split \t -- $path)[-1]
                if test (string sub --length 1 $original) = R
                    # path has been renamed and looks like "R LICENSE -> LICENSE.md"
                    # extract the path to use from after the arrow
                    set --append cleaned_paths (string split -- "-> " $original)[-1]
                else
                    set --append cleaned_paths (string sub --start=4 $original)
                end
            end

            commandline --current-token --replace -- (string join ' ' $cleaned_paths)
        end
    end

    commandline --function repaint
end
