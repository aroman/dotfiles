function _fzf_shorten_path --description "Shorten paths on stdin, emitting 'shortened\toriginal' per line. Like prompt_pwd -d 3 -D 2 but ~27x faster." --argument-names prefix_len
    # prefix_len: number of leading chars to preserve verbatim (e.g. 3 for git status "M  ")
    set -q prefix_len[1]; or set prefix_len 0
    awk -v plen="$prefix_len" '{
        line = $0
        prefix = ""
        rest = $0
        if (plen > 0) {
            prefix = substr($0, 1, plen)
            rest = substr($0, plen + 1)
        }
        n = split(rest, parts, "/")
        last = (substr(rest, length(rest)) == "/") ? n - 1 : n
        short = ""
        for (i = 1; i <= last; i++) {
            if (i > 1) short = short "/"
            if (i <= last - 2) short = short substr(parts[i], 1, 3)
            else short = short parts[i]
        }
        if (substr(rest, length(rest)) == "/") short = short "/"
        printf "%s%s\t%s\n", prefix, short, line
    }'
end
