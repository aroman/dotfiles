set fish_greeting ""

# Everblush color theme
set -g fish_color_autosuggestion 6e7679
set -g fish_color_cancel -r
set -g fish_color_command 67b0e8
set -g fish_color_comment 5c6568
set -g fish_color_end 6cbfbf
set -g fish_color_error e57474
set -g fish_color_escape c47fd5
set -g fish_color_history_current --bold
set -g fish_color_match --background=3f515a
set -g fish_color_normal dadada
set -g fish_color_operator 6cbfbf
set -g fish_color_param dadada
set -g fish_color_quote e5c76b
set -g fish_color_redirection c47fd5
set -g fish_color_search_match --background=3f515a
set -g fish_color_selection dadada --bold --background=3f515a
set -g fish_color_valid_path --underline
set -g fish_pager_color_completion b3b9b8
set -g fish_pager_color_description 8a9294
set -g fish_pager_color_prefix 67b0e8 --underline
set -g fish_pager_color_progress dadada --background=232a2d

if status --is-interactive
    starship init fish | source
end

set fzf_preview_dir_cmd eza --color=always --icons -la
set fzf_preview_file_cmd _fzf_preview_file_cmd
set fzf_diff_highlighter delta --paging=never

# Everblush LS_COLORS — calm palette: only dirs/symlinks/executables get accents
set -x LS_COLORS "di=38;2;141;181;200:ln=38;2;137;181;181:or=38;2;184;138;138:ex=1;38;2;140;207;126"

# fzf Everblush theme
set -x FZF_DEFAULT_OPTS \
    --cycle --layout=reverse --border=none --height=90% --preview-window=wrap,border-left --marker='*' --scrollbar='█' --input-border --no-separator --info=inline-right \
    --bind='ctrl-/:toggle-preview,ctrl-a:select-all,ctrl-d:deselect-all,ctrl-y:preview-up,ctrl-e:preview-down' \
    --color='fg:#dadada,bg:-1,hl:#67b0e8,fg+:#b3b9b8,bg+:#232a2d,hl+:#6cbfbf,info:#b3b9b8,prompt:#8ccf7e,pointer:#8ccf7e,marker:#8ccf7e,spinner:#e5c76b,header:#67b0e8,border:#2a3538,list-border:#2a3538,scrollbar:#3a4548,separator:#2a3538,gutter:#1e2528'
