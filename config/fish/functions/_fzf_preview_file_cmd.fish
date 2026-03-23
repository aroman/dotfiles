function _fzf_preview_file_cmd --description "Preview files in fzf with image support"
    set -f file_path $argv

    set -l mime (file --brief --dereference --mime -- "$file_path")

    if string match -q "image/*" -- $mime
        set -l dim {$FZF_PREVIEW_COLUMNS}x{$FZF_PREVIEW_LINES}
        if set -q KITTY_WINDOW_ID; or set -q GHOSTTY_RESOURCES_DIR; and command -q kitten
            kitten icat --clear --transfer-mode=memory --unicode-placeholder --stdin=no --place="$dim@0x0" "$file_path" | sed '$d' | sed '$s/$/\e[m/'
        else if command -q chafa
            chafa -s "$dim" "$file_path"
        else
            file "$file_path"
        end
    else if string match -q "*binary*" -- $mime
        file "$file_path"
    else
        bat --style=numbers --color=always "$file_path"
    end
end
