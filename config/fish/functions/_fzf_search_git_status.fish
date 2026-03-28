function _fzf_search_git_status --description "Search the output of git status. Replace the current token with the selected file paths."
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo '_fzf_search_git_status: Not in a git repository.' >&2
    else
        set -f preview_cmd 'echo; _fzf_preview_changed_file {2}'
        if set --query fzf_diff_highlighter
            set preview_cmd "$preview_cmd | $fzf_diff_highlighter"
        end

        set -f selected_paths (
            git status --short |
            while read -l line
                set -l status_prefix (string sub -l 3 -- $line)
                set -l path (string sub -s 4 -- $line)
                printf '%s%s\t%s\n' $status_prefix (prompt_pwd -d 1 -D 2 -- $path) $line
            end |
            _fzf_wrapper --ansi \
                --multi \
                --prompt=" " \
                --query=(commandline --current-token) \
                --preview=$preview_cmd \
                --delimiter='\t' \
                --with-nth=1 \
                --accept-nth=2 \
                --preview-border --preview-label-pos=2 --bind='focus:transform-preview-label:printf "\033[1m %s \033[0m" {2}' \
                $fzf_git_status_opts
        )
        if test $status -eq 0
            # git status --short automatically escapes the paths of most files for us so not going to bother trying to handle
            # the few edges cases of weird file names that should be extremely rare (e.g. "this;needs;escaping")
            set -f cleaned_paths

            for path in $selected_paths
                if test (string sub --length 1 $path) = R
                    # path has been renamed and looks like "R LICENSE -> LICENSE.md"
                    # extract the path to use from after the arrow
                    set --append cleaned_paths (string split -- "-> " $path)[-1]
                else
                    set --append cleaned_paths (string sub --start=4 $path)
                end
            end

            commandline --current-token --replace -- (string join ' ' $cleaned_paths)
        end
    end

    commandline --function repaint
end
