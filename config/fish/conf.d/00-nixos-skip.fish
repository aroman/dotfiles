# Skip /etc/fish/config.fish's body. NixOS sources two empty foreign-env scripts
# via `fenv source`, which spawns a bash subshell per call — ~30ms of pure
# overhead for nothing. Setting these guards makes /etc/fish/config.fish a no-op
# and we replicate the useful parts below.
#
# Trade-off: if `programs.fish.shellInit`/`interactiveShellInit`/`loginShellInit`
# ever gets set in NixOS, it will silently NOT be applied — remove this file then.
set -g __fish_nixos_general_config_sourced 1
set -g __fish_nixos_interactive_config_sourced 1
set -g __fish_nixos_login_config_sourced 1

if status is-interactive
    if test -d /etc/fish/generated_completions
        set -l prev (string join0 $fish_complete_path | string match --regex "^.*?(?=\x00[^\x00]*generated_completions.*)" | string split0 | string match -er ".")
        set -l post (string join0 $fish_complete_path | string match --regex "[^\x00]*generated_completions.*" | string split0 | string match -er ".")
        set fish_complete_path $prev /etc/fish/generated_completions $post
    end

    command -q direnv; and direnv hook fish | source
end
