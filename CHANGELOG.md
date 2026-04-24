# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-04-24

Initial public release.

### Added

- Single-file `statusline.sh` with no runtime dependencies beyond `bash` (3.2+),
  `jq`, `git`, and `date`. Works on Linux, macOS, and WSL2.
- Three-line layout:
  - Line 1 — `cwd · branch · PEAK TIME` (PEAK TIME only during the Anthropic
    weekday 13:00–19:00 UTC accelerated-quota-burn window).
  - Line 2 — `model · effort · thinking · version · duration · context bar`,
    with effort-level glyphs matching Claude Code's own UI
    (`○ low`, `◐ medium`, `● high`, `◉ xhigh`, `◈ max`).
  - Line 3 — `5h rate limit · weekly rate limit`, each with its reset clock
    rendered in the user's local timezone and locale's 12h/24h preference.
- `CLAUDE_STATUSLINE_*` env-var configuration surface: bar width, empty-cell
  rendering, timezone suffix, peak-time hide flag, 12h/24h force, demo mode.
- `NO_COLOR` support (de-facto accessibility standard).
- `scripts/install.sh` one-liner installer that patches
  `~/.claude/settings.json` with a backup-before-overwrite guardrail.
- `AGENTS.md` copy-paste prompt so coding agents can set the script up end to end.
- GitHub Actions CI: `shellcheck`, `shfmt`, Linux + macOS smoke tests,
  `bats` integration tests, personal-data leak scan.
- GitHub Actions release workflow that attaches `statusline.sh` and
  `scripts/install.sh` to every `v*.*.*` tag.

### Performance

- ≈ 55 ms per prompt refresh on a modern Linux box. Achieved by consolidating
  all JSON parsing into one `jq` call, sharing a single `_NOW` clock across the
  three reset computations, inlining gradient math (no subshell per cell), and
  using bash builtins in place of `basename` / `test`.
