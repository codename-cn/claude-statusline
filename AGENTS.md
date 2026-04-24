# Setup via AI agent

If you already use an AI coding agent (Claude Code, Cursor, Aider, Codex, Continue, etc.) you can hand it this file — or just the prompt block below — and it will set up `claude-statusline` end-to-end without you having to copy commands.

**If you are the agent reading this:** follow the steps in order, stop at every "PAUSE" marker and let the human act before you continue. Never overwrite an existing `~/.claude/settings.json` without backing it up and confirming with the human first.

---

## Copy-paste prompt

```text
Please set up `claude-statusline` on this machine for me. It is a three-line
statusline for Claude Code that shows cwd, git branch, context-window fill,
5-hour + weekly rate limits, and a peak-hours indicator for Anthropic's
weekday 13:00–19:00 UTC quota-burn window. Follow the instructions in
claude-statusline's AGENTS.md exactly. Specifically:

1. Verify `bash` (3.2+), `jq`, and `git` are on PATH. If `jq` is missing,
   tell me the install command for my OS and stop.
2. Verify Claude Code is already installed (the `~/.claude/` directory
   exists). If not, direct me to https://claude.com/claude-code and stop.
3. Download the statusline script:
      mkdir -p ~/.claude
      curl -fsSL https://raw.githubusercontent.com/codename-cn/claude-statusline/main/statusline.sh \
          -o ~/.claude/statusline.sh
      chmod +x ~/.claude/statusline.sh
4. Patch ~/.claude/settings.json to register the statusline:
     {
       "statusLine": {
         "type": "command",
         "command": "bash ~/.claude/statusline.sh"
       }
     }
   If settings.json already has a `statusLine` entry with a DIFFERENT
   command, back it up to ~/.claude/settings.json.bak-<timestamp> and ASK
   me before overwriting. Never silently replace someone's existing
   custom statusline.
5. Run the script once with a synthetic payload to sanity-check:
     echo '{"cwd":"/tmp","version":"probe","model":{"display_name":"test"}}' \
         | bash ~/.claude/statusline.sh
   The output should be two non-empty lines and no error messages.
6. Tell me to restart Claude Code (or open a new session) and confirm the
   new statusline appears.

Never modify files outside of ~/.claude/ during setup. Never hardcode my
name, email, or any credential into the script or settings.
```

---

## What the agent must NOT do

- Do not silently overwrite a pre-existing `statusLine.command` in `settings.json` — always back up and confirm.
- Do not edit `~/.claude/settings.local.json` (that is for user-local overrides not controlled by us).
- Do not install `jq`, `git`, or `bash` via a package manager without explicit human consent.
- Do not pipe this repo's `install.sh` through `sudo`. The script operates entirely in the user's home directory.
- Do not commit `~/.claude/settings.json` to any repository.

## Verification checklist

After setup the agent should confirm each of these:

- [ ] `test -x ~/.claude/statusline.sh` succeeds.
- [ ] `jq -r '.statusLine.command' ~/.claude/settings.json` prints `bash ~/.claude/statusline.sh` (or equivalent).
- [ ] A synthetic-JSON run (as shown in step 5 of the prompt) produces two non-empty lines and no errors.
- [ ] Opening a new Claude Code session shows the three-line statusline with colored bars.

If any of these fail, report the exact output and stop — do not try to "fix" it by guessing.

## Customizing after install

Environment variables recognized by the script are documented in [README.md](./README.md#configuration). Common tweaks:

- `export CLAUDE_STATUSLINE_PEAKTIME_HIDDEN=1` — hide the peak-hours indicator.
- `export CLAUDE_STATUSLINE_SHOW_TZ=1` — append timezone abbr to reset clocks.
- `export CLAUDE_STATUSLINE_BAR_WIDTH=20` — wider bars.
- `export NO_COLOR=1` — disable color (for screen readers, log files, dumb terminals).

Add them to your shell rc, not to `settings.json`. Claude Code runs the statusline in an inherited shell environment.
