function xr --wraps 'codex --yolo resume' --description 'codex resume; auto-open the session when it is the only one for this dir'
    set -l resume codex --yolo resume

    # Any explicit argument (a session id, --all, --last, --include-non-interactive, …)
    # bypasses the auto logic and goes straight to codex.
    if set -q argv[1]
        $resume $argv
        return
    end

    # Find the interactive sessions recorded for the current directory — the same
    # scope the resume picker uses: match cwd, exclude `codex exec` runs and subagent
    # (review/explorer) threads. Subagents have used both thread_source and
    # source.subagent across Codex versions.
    #
    # session_meta is always the first JSONL line, so narrow to files that even
    # mention this cwd (ripgrep, parallel), then verify the exact cwd on line 1.
    # Narrowing keeps the count *exact* — jq still does the real comparison — it just
    # avoids reading every session file as history grows.
    set -l ids (
        rg -l -F --null --no-messages '"cwd":"'$PWD'"' ~/.codex/sessions 2>/dev/null \
        | xargs -0 -r head -qn1 2>/dev/null \
        | jq -rs --arg cwd "$PWD" '
            .[]
            | select(
                .payload.cwd == $cwd
                and .payload.originator != "codex_exec"
                and ((.payload.thread_source // "") != "subagent")
                and ((.payload.source.subagent? // "") == "")
              )
            | .payload.id' 2>/dev/null
    )

    if test (count $ids) -eq 1
        # Exactly one session here → skip the picker and open it directly.
        $resume $ids[1]
    else
        # Zero or many → fall back to the normal picker.
        $resume
    end
end
