#!/usr/bin/env bash
#
# claude-statusline — a three-line statusline for Claude Code
# https://github.com/codename-cn/claude-statusline
#
# Renders on every prompt refresh:
#   Line 1: cwd · git branch · PEAKTIME indicator (only during Anthropic's
#           weekday 13:00–19:00 UTC accelerated-quota-burn window)
#   Line 2: model · effort · version · session duration · context-window bar
#   Line 3: 5h rate limit · weekly rate limit
#
# Dependencies: bash 3.2+, jq, GNU or BSD date, a truecolor-capable terminal.
#
# Configuration (all optional, set via env or your shell rc):
#
#   NO_COLOR=1                          Disable all ANSI color (de-facto standard).
#   CLAUDE_STATUSLINE_BAR_WIDTH=15      Width (cells) of progress bars.
#   CLAUDE_STATUSLINE_EMPTY_HIDDEN=1    (default) Hide the empty portion of bars.
#   CLAUDE_STATUSLINE_EMPTY_HIDDEN=0    Show empty cells as dim boxes.
#   CLAUDE_STATUSLINE_EMPTY_RGB="r;g;b" Color for empty cells when shown (default 128;128;128).
#   CLAUDE_STATUSLINE_SHOW_TZ=1         Append timezone abbr (e.g. CEST) to reset times.
#   CLAUDE_STATUSLINE_PEAKTIME_HIDDEN=1 Hide the peaktime indicator entirely.
#   CLAUDE_STATUSLINE_FORCE_12H=1       Force 12-hour clock (default: follow locale).
#   CLAUDE_STATUSLINE_FORCE_24H=1       Force 24-hour clock (default: follow locale).
#   CLAUDE_STATUSLINE_DEMO=1            Demo mode: override all quota %, reset
#                                       times, and peaktime to show the full
#                                       layout at maximum saturation. Useful
#                                       for sanity-checking terminal rendering.
#
# Licensed MIT. No warranty. See README.md for details.

set -o pipefail

# Single clock reading reused everywhere — saves three `date +%s` forks per
# refresh (peaktime segment, 5h reset, weekly reset).
_NOW=$(date +%s)

# ---------------------------------------------------------------------------
# Fail fast on missing jq — we parse JSON on every refresh.
# ---------------------------------------------------------------------------
if ! command -v jq > /dev/null 2>&1; then
    printf 'claude-statusline: jq not found on PATH — install it and retry.\n' >&2
    exit 0
fi

# ---------------------------------------------------------------------------
# Colors (honor NO_COLOR).
# ---------------------------------------------------------------------------
if [ -n "${NO_COLOR:-}" ]; then
    CYAN=""
    RESET=""
    _COLOR_ENABLED=0
else
    CYAN=$'\033[36m'
    RESET=$'\033[0m'
    _COLOR_ENABLED=1
fi

BAR_WIDTH="${CLAUDE_STATUSLINE_BAR_WIDTH:-15}"
EMPTY_RGB="${CLAUDE_STATUSLINE_EMPTY_RGB:-128;128;128}"
EMPTY_HIDDEN="${CLAUDE_STATUSLINE_EMPTY_HIDDEN:-1}"

# ---------------------------------------------------------------------------
# Portable date-from-epoch: GNU date uses `-d @N`, BSD/macOS date uses `-r N`.
# Detected once, called everywhere.
# ---------------------------------------------------------------------------
if date -d "@0" +%s > /dev/null 2>&1; then
    _date_from_epoch() { date -d "@$1" "+$2" 2> /dev/null; }
else
    _date_from_epoch() { date -r "$1" "+$2" 2> /dev/null; }
fi

# ---------------------------------------------------------------------------
# Gradient: blue → amber → orange → red, keyed by 0..100 percent.
#
# _gradient_rgb_at_pct stays as a separate function because it's called for
# the colored % text three times per refresh. The hot path — rendering 15
# gradient cells per bar, three bars per refresh — inlines the same math
# inside render_gradient_bar to avoid ~45 subshell forks per refresh.
# ---------------------------------------------------------------------------
_gradient_rgb_at_pct() {
    local pct=$1 scaled t r g b
    [ "$pct" -lt 0 ] 2> /dev/null && pct=0
    [ "$pct" -gt 100 ] 2> /dev/null && pct=100
    scaled=$((pct * 10))
    if [ "$scaled" -lt 333 ]; then
        t=$((scaled * 1000 / 333))
        r=$(((91 * (1000 - t) + 245 * t) / 1000))
        g=$(((158 * (1000 - t) + 200 * t) / 1000))
        b=$(((245 * (1000 - t) + 91 * t) / 1000))
    elif [ "$scaled" -lt 666 ]; then
        t=$(((scaled - 333) * 1000 / 333))
        r=$(((245 * (1000 - t) + 255 * t) / 1000))
        g=$(((200 * (1000 - t) + 140 * t) / 1000))
        b=$(((91 * (1000 - t) + 66 * t) / 1000))
    else
        t=$(((scaled - 666) * 1000 / 334))
        r=$(((255 * (1000 - t) + 245 * t) / 1000))
        g=$(((140 * (1000 - t) + 91 * t) / 1000))
        b=$(((66 * (1000 - t) + 91 * t) / 1000))
    fi
    printf '%d;%d;%d' "$r" "$g" "$b"
}

gradient_color_at_pct() {
    [ "$_COLOR_ENABLED" = 0 ] && return
    local rgb
    rgb=$(_gradient_rgb_at_pct "$1")
    printf '\033[38;2;%sm' "$rgb"
}

# Per-cell gradient bar with the color math INLINED — no subshell per cell.
# For a 15-cell bar rendered three times per refresh, that removes 45 forks.
render_gradient_bar() {
    local filled=$1 width=$2
    local i pct scaled t r g b esc result=""
    local denom=$((width > 1 ? width - 1 : 1))
    for ((i = 0; i < width; i++)); do
        if [ "$i" -lt "$filled" ]; then
            if [ "$_COLOR_ENABLED" = 1 ]; then
                pct=$((i * 100 / denom))
                scaled=$((pct * 10))
                if [ "$scaled" -lt 333 ]; then
                    t=$((scaled * 1000 / 333))
                    r=$(((91 * (1000 - t) + 245 * t) / 1000))
                    g=$(((158 * (1000 - t) + 200 * t) / 1000))
                    b=$(((245 * (1000 - t) + 91 * t) / 1000))
                elif [ "$scaled" -lt 666 ]; then
                    t=$(((scaled - 333) * 1000 / 333))
                    r=$(((245 * (1000 - t) + 255 * t) / 1000))
                    g=$(((200 * (1000 - t) + 140 * t) / 1000))
                    b=$(((91 * (1000 - t) + 66 * t) / 1000))
                else
                    t=$(((scaled - 666) * 1000 / 334))
                    r=$(((255 * (1000 - t) + 245 * t) / 1000))
                    g=$(((140 * (1000 - t) + 91 * t) / 1000))
                    b=$(((66 * (1000 - t) + 91 * t) / 1000))
                fi
                printf -v esc '\033[38;2;%d;%d;%dm█' "$r" "$g" "$b"
            else
                esc='#'
            fi
            result+="$esc"
        elif [ "$EMPTY_HIDDEN" = 0 ]; then
            if [ "$_COLOR_ENABLED" = 1 ]; then
                printf -v esc '\033[38;2;%sm░' "$EMPTY_RGB"
            else
                esc='.'
            fi
            result+="$esc"
        fi
    done
    printf '%s%s' "$result" "$RESET"
}

rate_limit_bar() {
    local pct=$1
    local filled=$(((pct * BAR_WIDTH + 50) / 100))
    render_gradient_bar "$filled" "$BAR_WIDTH"
}

# ---------------------------------------------------------------------------
# Locale-aware clock formatting. Respects the system's 12h/24h preference
# unless the user forces one via env.
# ---------------------------------------------------------------------------
_locale_use_12h() {
    if [ -n "${CLAUDE_STATUSLINE_FORCE_12H:-}" ]; then return 0; fi
    if [ -n "${CLAUDE_STATUSLINE_FORCE_24H:-}" ]; then return 1; fi
    local tfmt
    tfmt=$(locale t_fmt 2> /dev/null)
    [[ "$tfmt" == *%p* || "$tfmt" == *%r* ]]
}

_tz_suffix() {
    [ -n "${CLAUDE_STATUSLINE_SHOW_TZ:-}" ] || return 0
    local tz
    tz=$(date "+%Z" 2> /dev/null)
    [ -n "$tz" ] && printf ' %s' "$tz"
}

format_local_time() {
    local ts=$1 clock suffix
    if _locale_use_12h; then
        clock=$(_date_from_epoch "$ts" "%-I:%M %p")
    else
        clock=$(_date_from_epoch "$ts" "%H:%M")
    fi
    suffix=$(_tz_suffix)
    printf '%s%s' "$clock" "$suffix"
}

format_local_datetime() {
    local ts=$1 clock suffix
    if _locale_use_12h; then
        clock=$(_date_from_epoch "$ts" "%a %-I:%M %p")
    else
        clock=$(_date_from_epoch "$ts" "%a %H:%M")
    fi
    suffix=$(_tz_suffix)
    printf '%s%s' "$clock" "$suffix"
}

format_5h_reset() {
    local reset_ts=$1
    local secs=$((reset_ts - _NOW))
    local clock
    clock=$(format_local_time "$reset_ts")
    if ((secs <= 0)); then
        [ -n "$clock" ] && printf '%s (0h 0m)' "$clock" || printf '0h 0m'
        return
    fi
    local h=$((secs / 3600)) m=$(((secs % 3600) / 60))
    [ -n "$clock" ] && printf '%s (%dh %dm)' "$clock" "$h" "$m" || printf '%dh %dm' "$h" "$m"
}

format_weekly_reset() {
    local reset_ts=$1
    local secs=$((reset_ts - _NOW))
    local clock
    clock=$(format_local_datetime "$reset_ts")
    if ((secs <= 0)); then
        [ -n "$clock" ] && printf '%s (0d 0h 0m)' "$clock" || printf '0d 0h 0m'
        return
    fi
    local total_m=$((secs / 60))
    local h=$((total_m / 60))
    local m=$((total_m % 60))
    local d=$((h / 24))
    h=$((h % 24))
    [ -n "$clock" ] && printf '%s (%dd %dh %dm)' "$clock" "$d" "$h" "$m" ||
        printf '%dd %dh %dm' "$d" "$h" "$m"
}

# ---------------------------------------------------------------------------
# Peaktime indicator.
#
# Anthropic quietly rolled out a weekday quota-burn acceleration window on
# 2026-03-27 (community-observed, not officially documented). During the
# window, sessions count against your 5-hour and weekly limits at an
# accelerated rate. Window: Monday–Friday, 13:00–19:00 UTC.
#
# Rendered only while the window is open — the status line stays quiet the
# rest of the time.
# ---------------------------------------------------------------------------
PEAKTIME_START_UTC=13 # inclusive
PEAKTIME_END_UTC=19   # exclusive

_emit_peaktime_label() {
    local peaktime_end=$1
    local delta=$((peaktime_end - _NOW))
    local h=$((delta / 3600))
    local m=$(((delta % 3600) / 60))
    local clock label
    clock=$(format_local_time "$peaktime_end")
    if ((_COLOR_ENABLED)); then
        label=$'\033[1;38;2;245;91;91m'"PEAK TIME${RESET}" # bold red
    else
        label="PEAK TIME"
    fi
    if [ -n "$clock" ]; then
        printf '%s ends %s (%dh %dm)' "$label" "$clock" "$h" "$m"
    else
        printf '%s ends in %dh %dm' "$label" "$h" "$m"
    fi
}

render_peaktime_segment() {
    [ "${CLAUDE_STATUSLINE_PEAKTIME_HIDDEN:-0}" = 1 ] && return

    # Demo mode: pretend we are 3 hours before peaktime end.
    if [ "${CLAUDE_STATUSLINE_DEMO:-0}" = 1 ]; then
        _emit_peaktime_label $((_NOW + 3 * 3600))
        return
    fi

    local dow_utc h_utc m_utc s_utc secs_into_day peaktime_end
    # One date fork for all UTC fields instead of four.
    read -r dow_utc h_utc m_utc s_utc < <(date -u +'%u %H %M %S')

    # Weekend → always off-peak.
    ((dow_utc >= 6)) && return

    # 10# forces base-10 parsing so leading zeros don't trigger octal errors.
    secs_into_day=$((10#$h_utc * 3600 + 10#$m_utc * 60 + 10#$s_utc))

    # Outside today's peaktime window → render nothing.
    if ((secs_into_day < PEAKTIME_START_UTC * 3600)) ||
        ((secs_into_day >= PEAKTIME_END_UTC * 3600)); then
        return
    fi

    peaktime_end=$((_NOW - secs_into_day + PEAKTIME_END_UTC * 3600))
    _emit_peaktime_label "$peaktime_end"
}

# ---------------------------------------------------------------------------
# Input: Claude Code pipes the session JSON to stdin on every refresh.
# ---------------------------------------------------------------------------
input=$(cat)
if [ -z "$input" ]; then
    # No input — nothing to render. Don't error; Claude Code may probe us dry.
    exit 0
fi

# ---------------------------------------------------------------------------
# One jq call pulls out every field we need, NUL-delimited so no field
# content (even with embedded tabs/newlines) can break parsing. Replaces
# 13 individual jq forks with 1.
# ---------------------------------------------------------------------------
_fields=()
while IFS= read -r -d '' _f; do
    _fields+=("$_f")
done < <(printf '%s' "$input" | jq -j '
    (.cwd // ""), "\u0000",
    (.version // ""), "\u0000",
    (.model.display_name // .model.id // ""), "\u0000",
    (.effort.level // .effort_level // .effortLevel // ""), "\u0000",
    (.thinking.enabled // false | tostring), "\u0000",
    (.cost.total_duration_ms // 0 | tostring), "\u0000",
    (.context_window.used_percentage // "" | tostring), "\u0000",
    (.context_window.context_window_size // "" | tostring), "\u0000",
    (.rate_limits.five_hour.used_percentage // "" | tostring), "\u0000",
    (.rate_limits.five_hour.resets_at // "" | tostring), "\u0000",
    (.rate_limits.seven_day.used_percentage // "" | tostring), "\u0000",
    (.rate_limits.seven_day.resets_at // "" | tostring), "\u0000"
')

cwd_path="${_fields[0]:-}"
version="${_fields[1]:-}"
model="${_fields[2]:-}"
effort="${_fields[3]:-}"
thinking="${_fields[4]:-}"
duration_ms="${_fields[5]:-0}"
ctx_pct="${_fields[6]:-}"
ctx_total="${_fields[7]:-}"
rl_5h="${_fields[8]:-}"
rl_5h_reset="${_fields[9]:-}"
rl_7d="${_fields[10]:-}"
rl_7d_reset="${_fields[11]:-}"

# Demo mode — overrides every live field with a synthetic saturated payload
# so users can sanity-check how the full layout renders on their terminal.
if [ "${CLAUDE_STATUSLINE_DEMO:-0}" = 1 ]; then
    ctx_pct=100
    [ -z "$ctx_total" ] || ((ctx_total <= 0)) && ctx_total=200000
    rl_5h=100
    rl_7d=100
    rl_5h_reset=$((_NOW + 7200))   # in 2 h
    rl_7d_reset=$((_NOW + 500000)) # in ~5.8 d
fi

# Effort fallback chain (JSON → env → settings.json).
if [ -z "$effort" ] && [ -n "${CLAUDE_CODE_EFFORT_LEVEL:-}" ]; then
    effort="$CLAUDE_CODE_EFFORT_LEVEL"
fi
if [ -z "$effort" ] && [ -f "$HOME/.claude/settings.json" ]; then
    effort=$(jq -r '.effortLevel // empty' "$HOME/.claude/settings.json" 2> /dev/null)
fi

# ---------------------------------------------------------------------------
# Helpers whose output feeds directly into the three lines.
# `--` separators defend against paths that start with `-`.
# ---------------------------------------------------------------------------
current_dir=""
# Pure-bash basename (no fork): strip every character up to and including
# the last `/` in the path. Handles trailing slashes gracefully.
if [ -n "$cwd_path" ]; then
    _tmp=${cwd_path%/}
    current_dir=${_tmp##*/}
    unset _tmp
fi

branch=""
if [ -n "$cwd_path" ] && git -C "$cwd_path" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd_path" symbolic-ref --short HEAD 2> /dev/null ||
        git -C "$cwd_path" rev-parse --short HEAD 2> /dev/null)
fi

format_tokens() {
    local n=$1
    if [ "$n" -ge 1000000 ] 2> /dev/null; then
        local m=$((n / 1000000)) remainder=$(((n % 1000000) / 100000))
        if [ "$remainder" -gt 0 ]; then
            printf '%d.%dM' "$m" "$remainder"
        else
            printf '%dM' "$m"
        fi
    elif [ "$n" -ge 1000 ] 2> /dev/null; then
        printf '%dk' $((n / 1000))
    else
        printf '%d' "$n"
    fi
}

# Context-window bar (goes on line 2 after the duration).
context_bar=""
if [ -n "$ctx_pct" ]; then
    ctx_pct=${ctx_pct%.*}
    [ "$ctx_pct" -gt 100 ] 2> /dev/null && ctx_pct=100
    _filled=$(((ctx_pct * BAR_WIDTH + 50) / 100))

    _token_label=""
    if [ -n "$ctx_total" ] && [ "$ctx_total" -gt 0 ] 2> /dev/null; then
        _used=$((ctx_total * ctx_pct / 100))
        _token_label="$(format_tokens "$_used")/$(format_tokens "$ctx_total")"
    fi

    _bar=$(render_gradient_bar "$_filled" "$BAR_WIDTH")
    _color=$(gradient_color_at_pct "$ctx_pct")
    _fmt_pct=$(printf '%d%%' "$ctx_pct")
    if [ -n "$_token_label" ]; then
        context_bar="${_bar} ${_color}${_fmt_pct}${RESET} ${_token_label}"
    else
        context_bar="${_bar} ${_color}${_fmt_pct}${RESET}"
    fi
fi

# Session duration (h:mm).
duration_info=""
if [ "$duration_ms" -gt 0 ] 2> /dev/null; then
    _total_min=$((duration_ms / 60000))
    duration_info=$(printf '%d:%02d' $((_total_min / 60)) $((_total_min % 60)))
fi

# 5-hour and weekly rate-limit segments (line 3).
five_segment=""
if [ -n "$rl_5h" ]; then
    _rl5=${rl_5h%.*}
    _color=$(gradient_color_at_pct "$_rl5")
    five_segment="$(rate_limit_bar "$_rl5") ${_color}$(printf '%d%%' "$_rl5")${RESET}"
    [ -n "$rl_5h_reset" ] && five_segment+=" $(format_5h_reset "$rl_5h_reset")"
fi

week_segment=""
if [ -n "$rl_7d" ]; then
    _rl7=${rl_7d%.*}
    _color=$(gradient_color_at_pct "$_rl7")
    week_segment="$(rate_limit_bar "$_rl7") ${_color}$(printf '%d%%' "$_rl7")${RESET}"
    [ -n "$rl_7d_reset" ] && week_segment+=" $(format_weekly_reset "$rl_7d_reset")"
fi

peaktime_segment=$(render_peaktime_segment)

# ---------------------------------------------------------------------------
# Render. All three lines join their segments with " · ".
#
#   Line 1: cwd · branch · PEAKTIME    (PEAKTIME only during the burn window)
#   Line 2: model · effort · thinking · version · duration · context-bar
#   Line 3: 5h · weekly
# ---------------------------------------------------------------------------

# Generic " · " joiner — fills $REPLY to avoid a subshell fork.
_join_dot() {
    REPLY=""
    local seg
    for seg in "$@"; do
        [ -z "$seg" ] && continue
        if [ -z "$REPLY" ]; then
            REPLY=$seg
        else
            REPLY+=" · $seg"
        fi
    done
}

# Line 1.
_cwd_segment=""
[ -n "$current_dir" ] && _cwd_segment="${CYAN}${current_dir}${RESET}"
_join_dot "$_cwd_segment" "$branch" "$peaktime_segment"
[ -n "$REPLY" ] && printf '%s' "$REPLY"

# Effort level → glyph mapping, matching Claude Code's own UI symbols
# (extracted from the shipped binary):
#   ○ U+25CB  low     — empty circle
#   ◐ U+25D0  medium  — half-filled circle
#   ● U+25CF  high    — filled circle
#   ◉ U+25C9  xhigh   — filled circle with ring (fisheye)
#   ◈ U+25C8  max     — diamond containing a smaller diamond
# Inlined below (not a helper function) so the case-match doesn't cost a
# subshell on every refresh. Unknown / unset levels fall through to text.

# Line 2 — model/effort/thinking form a single space-joined group, which is
# then joined to version/duration/context via " · ".
_model_group=""
[ -n "$model" ] && _model_group=$model
if [ -n "$effort" ]; then
    [ -n "$_model_group" ] && _model_group+=" "
    case "$effort" in
        low) _model_group+="○ $effort" ;;
        medium | med) _model_group+="◐ $effort" ;;
        high) _model_group+="● $effort" ;;
        xhigh) _model_group+="◉ $effort" ;;
        max | ultra) _model_group+="◈ $effort" ;;
        *) _model_group+=$effort ;;
    esac
fi
if [ "$thinking" = "true" ]; then
    [ -n "$_model_group" ] && _model_group+=" "
    _model_group+="thinking"
fi
_join_dot "$_model_group" "$version" "$duration_info" "$context_bar"
[ -n "$REPLY" ] && printf '\n%s' "$REPLY"

# Line 3.
_join_dot "$five_segment" "$week_segment"
[ -n "$REPLY" ] && printf '\n%s' "$REPLY"

# Explicit success: the final conditional above would otherwise leak its own
# test-return as the script's exit status when the line is empty.
exit 0
