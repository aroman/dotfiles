function sudo --wraps sudo --description "sudo with red bg tint in ghostty"
    if set -q GHOSTTY_RESOURCES_DIR; and isatty stdout
        printf '\e]11;#1f1315\e\\'
        command sudo $argv
        set -l ret $status
        printf '\e]111\e\\'
        return $ret
    else
        command sudo $argv
    end
end
