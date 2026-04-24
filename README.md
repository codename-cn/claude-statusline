# claude-statusline

[![CI](https://github.com/codename-cn/claude-statusline/actions/workflows/ci.yml/badge.svg)](https://github.com/codename-cn/claude-statusline/actions/workflows/ci.yml)
[![Shell: bash 3.2+](https://img.shields.io/badge/bash-3.2%2B-1f425f.svg)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![shellcheck](https://img.shields.io/badge/shellcheck-clean-brightgreen.svg)](https://www.shellcheck.net/)

**A zero-dependency three-line statusline for [Claude Code](https://claude.com/claude-code)** — shows your cwd, git branch, context-window fill, 5-hour + weekly rate limits with reset clocks in *your* timezone, and a live **peak-hours indicator** that tells you when Claude's weekday quota-burn window is active so you can plan your heavy prompts accordingly.

```text
my-project · feat/new-feature · PEAK TIME ends 9:00 PM (2h 14m)
Opus 4.7 ● high thinking · 2.1.200 · 1:02 · █████░░░░░░░░░░ 34% 68k/200k
█████░░░░░░░░░░ 45% 5:42 PM (2h 14m) · █████████░░░░░░ 62% Mon 9:00 AM (2d 14h)
```

Single bash script, no runtime dependencies beyond `bash`, `jq`, and `date`. Works on Linux, macOS, WSL2. Respects [`NO_COLOR`](https://no-color.org/). Locale-aware clock (12h/24h). Configurable via environment variables.

> **Keywords:** claude code statusline · claude statusline · anthropic claude rate limit monitor · claude code peak hours indicator · bash statusline · claude-code customization · claude 5-hour quota bar

## 🤖 LLM Quickstart

1. Point your coding agent (Claude Code, Cursor, Aider, Codex, …) at [AGENTS.md](./AGENTS.md).
2. Prompt away — it will install and wire up everything end-to-end.

## 👋 Human Quickstart

Requires `bash` (3.2+), `jq`, `git`, a truecolor-capable terminal, and Claude Code already configured on this machine.

**1. One-liner install** (downloads the script to `~/.claude/statusline.sh` and patches `~/.claude/settings.json` after confirmation):

```sh
curl -fsSL https://raw.githubusercontent.com/codename-cn/claude-statusline/main/scripts/install.sh | bash
```

**2. Reload Claude Code** (or start a new session). That's it.

### Manual install

If you'd rather not pipe `curl` to `bash`:

```sh
mkdir -p ~/.claude
curl -fsSL https://raw.githubusercontent.com/codename-cn/claude-statusline/main/statusline.sh \
    -o ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Then add this to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
```

## What it shows

| Line | Segment | Source |
|---|---|---|
| 1 | Current directory (basename of `cwd`) | Claude Code JSON |
| 1 | Git branch (read from session cwd, not your shell's PWD) | `git -C <cwd>` |
| 1 | Peak-hours indicator: `PEAK TIME ends HH:MM` (only visible during the window) | Computed (UTC → local) |
| 2 | Model name · effort level (`○ low`, `◐ medium`, `● high`, `◉ xhigh`, `◈ max` — matches Claude Code's own icons) · `thinking` marker · version · session duration · context-window bar | Claude Code JSON |
| 3 | 5-hour rate-limit bar · `%` · reset clock in local time (`HH:MM (Xh Ym)`) | Claude Code JSON |
| 3 | Weekly rate-limit bar · `%` · reset datetime in local time (`Mon HH:MM (Xd Yh)`) | Claude Code JSON |

All clocks render in your system timezone. Duration counters are bounded and drop leading zeros for readability.

## About the peak-hours indicator

Since 2026-03-27 Anthropic has applied a quota-burn acceleration during weekday 13:00–19:00 UTC — roughly mid-afternoon in Central Europe, late morning on the US East Coast, early morning on the West Coast. During this window your 5-hour and weekly limits deplete **faster than during off-peak hours** (community-observed; not officially documented). Weekends are fully off-peak.

`claude-statusline` shows `PEAK TIME ends 9:00 PM (2h 14m)` in bold red while the window is open (time in your local timezone and locale's clock style, so you can plan around it). Off-peak, the segment disappears entirely — the status line stays quiet until your quota is actually burning faster.

Hide it even during peak: `export CLAUDE_STATUSLINE_PEAKTIME_HIDDEN=1`.

Sources:
- [TokenCalculator — Claude Peak Hours 2026](https://tokencalculator.com/blog/claude-peak-time-throttle-quota-drains-faster-weekdays-2026)
- [The Register — Anthropic admits Claude Code quotas running out too fast](https://www.theregister.com/2026/03/31/anthropic_claude_code_limits/)
- [TechRadar — Claude is limiting usage more aggressively during peak hours](https://www.techradar.com/ai-platforms-assistants/claude/claude-is-limiting-usage-more-aggressively-during-peak-hours-heres-what-changed)

## Configuration

All settings are environment variables — set them in your shell rc or pass them through `settings.json` via a wrapper. Everything has a sensible default.

| Variable | Default | Effect |
|---|---|---|
| `NO_COLOR` | unset | If set to anything, all ANSI color is disabled (de-facto standard, see [no-color.org](https://no-color.org/)). |
| `CLAUDE_STATUSLINE_BAR_WIDTH` | `15` | Width (cells) of the context-window and rate-limit bars. |
| `CLAUDE_STATUSLINE_EMPTY_HIDDEN` | `1` | Hide the empty portion of bars. Set to `0` to show them as dim boxes. |
| `CLAUDE_STATUSLINE_EMPTY_RGB` | `128;128;128` | ANSI RGB triplet for empty-cell color when `EMPTY_HIDDEN=0`. |
| `CLAUDE_STATUSLINE_SHOW_TZ` | unset | Append the timezone abbreviation (e.g. `CEST`) to reset times. Useful on remote/shared screens. |
| `CLAUDE_STATUSLINE_PEAKTIME_HIDDEN` | unset | Set to `1` to hide the peak-hours indicator entirely. |
| `CLAUDE_STATUSLINE_FORCE_12H` | unset | Force 12-hour clock. Overrides locale. |
| `CLAUDE_STATUSLINE_FORCE_24H` | unset | Force 24-hour clock. Overrides locale. |

## Platform support

| Platform | Status | Notes |
|---|---|---|
| Linux (any distro) | ✅ | Primary development target. |
| macOS | ✅ | BSD `date` detected automatically. |
| WSL2 | ✅ | |
| Windows native | ❌ | No bash. Use WSL2. |

Terminal requirements: truecolor (24-bit) ANSI. If yours doesn't support it, gradient cells fall back to gray — bar shapes still render. Set `NO_COLOR=1` to disable color entirely.

## Known quirks

### The peak-hours window is community-observed, not official

Anthropic has not published the exact window, multiplier, or on/off schedule. The 13:00–19:00 UTC weekday window used here is the one consistently reported by multiple third-party outlets and community threads since the late-March 2026 change. If Anthropic publishes an official schedule that differs, open an issue.

### Timezone shown is whatever `date` reports

`claude-statusline` uses the system's default timezone (via `date`). If you SSH into a host configured for a different timezone than your laptop, reset clocks and the peak indicator render in the *host's* zone. Fix it with `export TZ=Europe/Berlin` in your shell rc.

### macOS `date` does not support every GNU format specifier

We auto-detect GNU vs BSD `date` and only use specifiers supported by both (`%H`, `%M`, `%a`, `%-I`, `%p`, `%Z`). If you see garbled clocks on macOS, please open an issue with `date --version 2>&1` and `sw_vers` output.

## Contributing

Issues and PRs welcome. Please run `shellcheck statusline.sh` before opening a PR — CI enforces it.

---

> ⭐ **If you find this useful, [star the repo](https://github.com/codename-cn/claude-statusline)** — it helps other Claude Code users discover it.

## License

MIT — see [`LICENSE`](./LICENSE).
