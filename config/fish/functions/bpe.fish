function bpe --description 'Compose a bud prompt in $EDITOR, then send it'
    set -l tmp (mktemp -t budprompt.XXXXXX.md)
    eval $EDITOR (string escape -- $tmp)
    if not test -s $tmp
        echo "bpe: empty buffer, not sending" >&2
        rm -f $tmp
        return 1
    end
    bud new -p (cat $tmp | string collect)
    set -l code $status
    rm -f $tmp
    return $code
end
