function dot
    if test -f /run/.containerenv
        cd ~/.dotfiles
    else if test -f /run/ostree-booted
        distrobox enter dotfiles -- fish -c "cd ~/.dotfiles; exec fish"
    else
        cd ~/.dotfiles
    end
end
