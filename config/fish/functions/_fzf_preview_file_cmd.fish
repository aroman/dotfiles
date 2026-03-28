function _fzf_preview_file_cmd --description "Preview files in fzf with image support"
    set -f file_path $argv

    set -l mime (file --brief --dereference --mime -- "$file_path")

    if not string match -q "image/*" -- $mime
        if string match -q "*binary*" -- $mime
            file "$file_path"
        else
            bat --style=numbers --color=always "$file_path"
        end
        return
    end

    # Compute preview dimensions, falling back to terminal size outside fzf
    if test -n "$FZF_PREVIEW_COLUMNS" -a -n "$FZF_PREVIEW_LINES"
        set -f dim {$FZF_PREVIEW_COLUMNS}x{$FZF_PREVIEW_LINES}
    else
        set -f dim (stty size < /dev/tty | awk '{print $2 "x" $1}')
    end

    # Kitty graphics protocol via kitten icat (works in kitty and ghostty)
    # Uses unicode placeholders so fzf can position the image in its preview grid
    if set -q KITTY_WINDOW_ID; or set -q GHOSTTY_RESOURCES_DIR; and command -q kitten
        # Shared memory transfer is fastest but only works locally
        if test -n "$SSH_TTY"
            set -f transfer stream
        else
            set -f transfer memory
        end
        kitten icat --clear --transfer-mode=$transfer --unicode-placeholder --stdin=no --place="$dim@0x0" "$file_path"

    # Chafa fallback (symbol/braille art, works everywhere)
    else if command -q chafa
        # Sixel images touching the bottom of the screen cause scrolling artifacts
        # https://github.com/junegunn/fzf/issues/2544
        if test -n "$FZF_PREVIEW_TOP" -a -n "$FZF_PREVIEW_LINES"
            set -l rows (stty size < /dev/tty | string split ' ')[1]
            if test (math "$FZF_PREVIEW_TOP + $FZF_PREVIEW_LINES") -eq "$rows"
                set dim {$FZF_PREVIEW_COLUMNS}x(math "$FZF_PREVIEW_LINES - 1")
            end
        end
        chafa -s "$dim" "$file_path"

    else
        file "$file_path"
    end
end
