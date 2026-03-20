# Fish completions for Claude Code CLI
# Based on https://gist.github.com/r4ai/d3cb3360cd38b1ea0f28228b9473db0c
# Updated for Claude Code as of March 2026
# TODO: Replace with `claude completion fish` once merged:
#   https://github.com/anthropics/claude-code/pull/27395

complete -c claude -f

# Subcommands
set -l subcommands agents auth config doctor install mcp plugin plugins setup-token update upgrade

complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -xa "$subcommands"

# Options (top-level)
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l add-dir -d "Additional directories to allow tool access to" -rF
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l agent -d "Agent for the current session" -x
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l agents -d "JSON object defining custom agents" -x
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l allow-dangerously-skip-permissions -d "Enable bypassing permission checks as an option"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l allowedTools -l allowed-tools -d "Tool names to allow" -x
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l append-system-prompt -d "Append to the default system prompt" -x
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l betas -d "Beta headers for API requests" -x
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l brief -d "Enable SendUserMessage tool for agent-to-user communication"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l chrome -d "Enable Claude in Chrome integration"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -s c -l continue -d "Continue the most recent conversation"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l dangerously-skip-permissions -d "Bypass all permission checks"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -s d -l debug -d "Enable debug mode with optional category filtering" -x
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l debug-file -d "Write debug logs to a file" -rF
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l disable-slash-commands -d "Disable all skills"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l disallowedTools -l disallowed-tools -d "Tool names to deny" -x
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l effort -d "Effort level for the session" -xa "low medium high max"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l fallback-model -d "Fallback model when default is overloaded" -xa "sonnet opus haiku"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l file -d "File resources to download at startup" -x
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l fork-session -d "Create a new session ID when resuming"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l from-pr -d "Resume a session linked to a PR" -x
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -s h -l help -d "Display help"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l ide -d "Auto-connect to IDE on startup"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l include-partial-messages -d "Include partial message chunks"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l input-format -d "Input format" -xa "text stream-json"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l json-schema -d "JSON Schema for structured output" -x
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l max-budget-usd -d "Maximum dollar amount for API calls" -x
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l mcp-config -d "Load MCP servers from JSON files" -rF
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l mcp-debug -d "[DEPRECATED] Enable MCP debug mode"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l model -d "Model for the session" -xa "sonnet opus haiku"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -s n -l name -d "Set a display name for this session" -x
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l no-chrome -d "Disable Claude in Chrome integration"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l no-session-persistence -d "Disable session persistence"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l output-format -d "Output format" -xa "text json stream-json"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l permission-mode -d "Permission mode" -xa "acceptEdits bypassPermissions default dontAsk plan auto"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l plugin-dir -d "Load plugins from a directory" -rF
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -s p -l print -d "Print response and exit"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l replay-user-messages -d "Re-emit user messages from stdin on stdout"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -s r -l resume -d "Resume a conversation by session ID" -x
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l session-id -d "Use a specific session ID (UUID)" -x
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l setting-sources -d "Comma-separated setting sources" -xa "user project local"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l settings -d "Path to settings JSON or JSON string" -rF
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l strict-mcp-config -d "Only use MCP servers from --mcp-config"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l system-prompt -d "System prompt for the session" -x
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l tmux -d "Create a tmux session for the worktree"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l tools -d "Specify available tools" -x
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -l verbose -d "Override verbose mode setting"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -s v -l version -d "Output the version number"
complete -c claude -n "not __fish_seen_subcommand_from $subcommands" -s w -l worktree -d "Create a new git worktree for this session" -x

# config subcommand
complete -c claude -n "__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from set get list reset" -xa "set get list reset"
complete -c claude -n "__fish_seen_subcommand_from config" -s g -l global -d "Global configuration"

# mcp subcommand
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from list add remove enable disable" -xa "list add remove enable disable"

# install subcommand
complete -c claude -n "__fish_seen_subcommand_from install" -xa "stable latest"
