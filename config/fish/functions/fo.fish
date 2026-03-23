function fo
    command tree -C -fi --noreport | fzf --ansi --multi --preview 'fzf-preview.sh {}' | xargs open
end
