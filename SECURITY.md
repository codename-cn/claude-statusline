# Security policy

## Reporting a vulnerability

Please report suspected vulnerabilities by opening a [GitHub Security Advisory](https://github.com/codename-cn/claude-statusline/security/advisories/new) on the repo — not a public issue. We'll triage within one week.

## Scope

`claude-statusline` is a single bash script that reads JSON on stdin, parses a handful of fields via `jq`, queries `git` for the current branch of the *session's* cwd (not the shell's PWD), and renders three lines to stdout. It does not read or write any credential, token, or network resource.

In scope:

- Command injection via malicious values in the JSON payload piped by Claude Code (cwd, model name, version, etc.).
- Path-traversal or `git -C` behavior against an attacker-controlled cwd.
- Any escalation from "can inject into the statusline JSON" to arbitrary command execution.

Out of scope:

- The Claude Code binary itself — report those to Anthropic.
- `jq`, `bash`, `git`, `date` upstream bugs — report to their respective projects.
- The contents of `~/.claude/settings.json`, which Claude Code manages.

## Handling issue reports safely

If you're writing a PR, a bug report, or sharing logs:

- The statusline prints nothing sensitive by default, but if you run it under a custom wrapper that injects additional fields, redact anything that looks like a token, API key, or email address before pasting output into an issue.
- Share the synthetic JSON payload you used to reproduce a bug, not a real Claude Code session dump — real dumps include your cwd path, model details, and session duration.

## Threat model, briefly

`claude-statusline` trusts:

- The user running it (owner of `~/.claude/`, controls `settings.json`).
- The JSON payload piped in by Claude Code — all untrusted fields (`cwd`, `model.*`, `version`) are consumed via `jq -r` and never passed to `eval`, `sh -c`, or subshell command strings.
- The `git` binary on `$PATH`. `git -C <cwd>` is invoked only for `rev-parse` and `symbolic-ref`, which are read-only.

`claude-statusline` does **not** trust:

- The environment beyond its documented `CLAUDE_STATUSLINE_*` and `NO_COLOR` variables.
- Terminal escape sequences in the JSON payload — all string fields are interpolated via `printf '%s'`, never via `printf` format strings, and never via `echo -e`.
