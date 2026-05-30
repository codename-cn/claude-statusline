#!/usr/bin/env bats
#
# Integration tests for statusline.sh. Each test pipes a synthetic Claude
# Code JSON payload to the script and asserts on the rendered output. We
# force NO_COLOR to strip ANSI escapes so assertions can match plain text.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../statusline.sh"
    export NO_COLOR=1
    # Isolate from the test host's settings.json effort fallback.
    export HOME="$BATS_TEST_TMPDIR"
    unset CLAUDE_STATUSLINE_DEMO
    unset CLAUDE_STATUSLINE_PEAKTIME
    unset CLAUDE_CODE_EFFORT_LEVEL
    unset CLAUDE_STATUSLINE_SHOW_TZ
    unset CLAUDE_STATUSLINE_FORCE_12H
    unset CLAUDE_STATUSLINE_FORCE_24H
    unset CLAUDE_STATUSLINE_FORECAST
    unset CLAUDE_STATUSLINE_BAR_CONTEXT
    unset CLAUDE_STATUSLINE_BAR_5H
    unset CLAUDE_STATUSLINE_BAR_WEEKLY
}

# --- empty input --------------------------------------------------------

@test "empty stdin produces no output" {
    run bash -c ": | bash '$SCRIPT'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# --- cwd + line 1 -------------------------------------------------------

@test "cwd basename is rendered on line 1" {
    run bash -c 'echo "{\"cwd\":\"/tmp/sub/project-x\"}" | bash "'"$SCRIPT"'"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"project-x"* ]]
}

@test "cwd with trailing slash is handled" {
    run bash -c 'echo "{\"cwd\":\"/tmp/sub/project-y/\"}" | bash "'"$SCRIPT"'"'
    [[ "$output" == *"project-y"* ]]
}

# --- model + version + effort + thinking on line 2 ----------------------

@test "model display name appears on line 2" {
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"model\":{\"display_name\":\"Opus 4.7\"}}" | bash "'"$SCRIPT"'"'
    [[ "$output" == *"Opus 4.7"* ]]
}

@test "version separator uses middle dot" {
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"version\":\"2.1.200\",\"model\":{\"display_name\":\"M\"}}" | bash "'"$SCRIPT"'"'
    [[ "$output" == *"M · 2.1.200"* ]]
}

@test "thinking flag renders the 'thinking' marker" {
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"model\":{\"display_name\":\"M\"},\"thinking\":{\"enabled\":true}}" | bash "'"$SCRIPT"'"'
    [[ "$output" == *"thinking"* ]]
}

# --- effort level icons -------------------------------------------------

@test "effort=low renders empty-circle icon ○" {
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"model\":{\"display_name\":\"M\"},\"effort\":{\"level\":\"low\"}}" | bash "'"$SCRIPT"'"'
    [[ "$output" == *"○ low"* ]]
}

@test "effort=medium renders half-circle icon ◐" {
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"model\":{\"display_name\":\"M\"},\"effort\":{\"level\":\"medium\"}}" | bash "'"$SCRIPT"'"'
    [[ "$output" == *"◐ medium"* ]]
}

@test "effort=high renders filled-circle icon ●" {
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"model\":{\"display_name\":\"M\"},\"effort\":{\"level\":\"high\"}}" | bash "'"$SCRIPT"'"'
    [[ "$output" == *"● high"* ]]
}

@test "effort=xhigh renders fisheye icon ◉" {
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"model\":{\"display_name\":\"M\"},\"effort\":{\"level\":\"xhigh\"}}" | bash "'"$SCRIPT"'"'
    [[ "$output" == *"◉ xhigh"* ]]
}

@test "effort=max renders diamond-in-diamond icon ◈" {
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"model\":{\"display_name\":\"M\"},\"effort\":{\"level\":\"max\"}}" | bash "'"$SCRIPT"'"'
    [[ "$output" == *"◈ max"* ]]
}

@test "unknown effort level falls through to text-only" {
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"model\":{\"display_name\":\"M\"},\"effort\":{\"level\":\"whatever\"}}" | bash "'"$SCRIPT"'"'
    [[ "$output" == *"M whatever"* ]]
    [[ "$output" != *"○ whatever"* ]]
    [[ "$output" != *"◐ whatever"* ]]
    [[ "$output" != *"● whatever"* ]]
    [[ "$output" != *"◉ whatever"* ]]
    [[ "$output" != *"◈ whatever"* ]]
}

# --- rate-limit segments ------------------------------------------------

@test "5h rate-limit percentage appears on line 3" {
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"rate_limits\":{\"five_hour\":{\"used_percentage\":42}}}" | bash "'"$SCRIPT"'"'
    [[ "$output" == *"42%"* ]]
}

@test "weekly rate-limit percentage appears on line 3" {
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"rate_limits\":{\"seven_day\":{\"used_percentage\":77}}}" | bash "'"$SCRIPT"'"'
    [[ "$output" == *"77%"* ]]
}

# --- demo mode ----------------------------------------------------------

@test "demo mode forces 100% everywhere" {
    export CLAUDE_STATUSLINE_DEMO=1
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"model\":{\"display_name\":\"M\"}}" | bash "'"$SCRIPT"'"'
    [[ "$output" == *"100%"* ]]
}

@test "demo mode renders PEAK TIME label when peaktime opt-in is set" {
    export CLAUDE_STATUSLINE_DEMO=1
    export CLAUDE_STATUSLINE_PEAKTIME=1
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"model\":{\"display_name\":\"M\"}}" | bash "'"$SCRIPT"'"'
    [[ "$output" == *"PEAK TIME"* ]]
}

@test "demo mode hides PEAK TIME by default (opt-in not set)" {
    export CLAUDE_STATUSLINE_DEMO=1
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"model\":{\"display_name\":\"M\"}}" | bash "'"$SCRIPT"'"'
    [[ "$output" != *"PEAK TIME"* ]]
}

# --- separators ---------------------------------------------------------

@test "line 1 uses ' · ' between cwd and PEAK TIME in demo mode" {
    export CLAUDE_STATUSLINE_DEMO=1
    export CLAUDE_STATUSLINE_PEAKTIME=1
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"model\":{\"display_name\":\"M\"}}" | bash "'"$SCRIPT"'"'
    line1=$(printf '%s\n' "$output" | head -1)
    [[ "$line1" == *"tmp · PEAK TIME"* ]]
}

@test "line 3 uses ' · ' between 5h and weekly" {
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"rate_limits\":{\"five_hour\":{\"used_percentage\":10},\"seven_day\":{\"used_percentage\":20}}}" | bash "'"$SCRIPT"'"'
    [[ "$output" == *"10% · "* ]]
}

# --- NO_COLOR hygiene ---------------------------------------------------

@test "NO_COLOR strips every ANSI escape" {
    export CLAUDE_STATUSLINE_DEMO=1
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"model\":{\"display_name\":\"M\"},\"effort\":{\"level\":\"high\"}}" | bash "'"$SCRIPT"'"'
    esc=$(printf '\033')
    [[ "$output" != *"$esc"* ]]
}

# --- bar width ----------------------------------------------------------

@test "custom BAR_WIDTH is honored" {
    export CLAUDE_STATUSLINE_BAR_WIDTH=5
    # Allow empty cells to be shown so we can count cells deterministically.
    export CLAUDE_STATUSLINE_EMPTY_HIDDEN=0
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"context_window\":{\"used_percentage\":40,\"context_window_size\":1000}}" | bash "'"$SCRIPT"'"'
    # At 40 % × width 5 with half-up rounding → 2 filled + 3 empty. With
    # NO_COLOR on, filled cells render as '#' and empty as '.'.
    [[ "$output" == *"##..."* ]]
}

# --- forecast bracket --------------------------------------------------

@test "5h forecast bracket renders by default with a usable reset_ts" {
    # 45% used, 2h remaining of a 5h window → 3h elapsed → forecast 45*18000/10800 = 75%.
    local now reset
    now=$(date +%s)
    reset=$((now + 7200))
    run bash -c "echo '{\"cwd\":\"/tmp\",\"rate_limits\":{\"five_hour\":{\"used_percentage\":45,\"resets_at\":$reset}}}' | bash '$SCRIPT'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[→75%]"* ]]
}

@test "weekly forecast bracket renders by default with a usable reset_ts" {
    # 30% used, 4 days remaining of a 7d window → 3d elapsed.
    # forecast = 30 * 604800 / (3*86400) = 30 * 604800 / 259200 = 70%.
    local now reset
    now=$(date +%s)
    reset=$((now + 4 * 86400))
    run bash -c "echo '{\"cwd\":\"/tmp\",\"rate_limits\":{\"seven_day\":{\"used_percentage\":30,\"resets_at\":$reset}}}' | bash '$SCRIPT'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[→70%]"* ]]
}

@test "CLAUDE_STATUSLINE_FORECAST=0 suppresses both brackets" {
    export CLAUDE_STATUSLINE_FORECAST=0
    local now reset5 reset7
    now=$(date +%s)
    reset5=$((now + 7200))
    reset7=$((now + 4 * 86400))
    run bash -c "echo '{\"cwd\":\"/tmp\",\"rate_limits\":{\"five_hour\":{\"used_percentage\":45,\"resets_at\":$reset5},\"seven_day\":{\"used_percentage\":30,\"resets_at\":$reset7}}}' | bash '$SCRIPT'"
    [ "$status" -eq 0 ]
    # Plain percentages still appear.
    [[ "$output" == *"45%"* ]]
    [[ "$output" == *"30%"* ]]
    # But no forecast brackets.
    [[ "$output" != *"[→"* ]]
}

@test "stale reset_ts in the past suppresses the 5h forecast bracket" {
    # reset_ts already 5 minutes ago — JSON not yet refreshed.
    local now reset
    now=$(date +%s)
    reset=$((now - 300))
    run bash -c "echo '{\"cwd\":\"/tmp\",\"rate_limits\":{\"five_hour\":{\"used_percentage\":50,\"resets_at\":$reset}}}' | bash '$SCRIPT'"
    [ "$status" -eq 0 ]
    [[ "$output" != *"[→"* ]]
}

@test "missing resets_at suppresses only the affected segment's bracket" {
    # 5h has no reset_ts → no 5h bracket. Weekly has one → weekly bracket present.
    local now reset
    now=$(date +%s)
    reset=$((now + 4 * 86400))
    run bash -c "echo '{\"cwd\":\"/tmp\",\"rate_limits\":{\"five_hour\":{\"used_percentage\":50},\"seven_day\":{\"used_percentage\":30,\"resets_at\":$reset}}}' | bash '$SCRIPT'"
    [ "$status" -eq 0 ]
    # Weekly bracket present.
    [[ "$output" == *"[→70%]"* ]]
    # 5h bracket absent — no other "[→" earlier in the output. Strip the
    # full weekly bracket and confirm no bracket prefix remains.
    five_only="${output%%\[→70%]*}"
    [[ "$five_only" != *"[→"* ]]
}

@test "zero usage renders [→0%]" {
    local now reset
    now=$(date +%s)
    reset=$((now + 7200))
    run bash -c "echo '{\"cwd\":\"/tmp\",\"rate_limits\":{\"five_hour\":{\"used_percentage\":0,\"resets_at\":$reset}}}' | bash '$SCRIPT'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[→0%]"* ]]
}

@test "very fresh window with high usage caps the forecast at 999%" {
    # 1% elapsed (180s of 18000s), but 50% already used → raw forecast 5000% → cap at 999%.
    local now reset
    now=$(date +%s)
    reset=$((now + 18000 - 180))
    run bash -c "echo '{\"cwd\":\"/tmp\",\"rate_limits\":{\"five_hour\":{\"used_percentage\":50,\"resets_at\":$reset}}}' | bash '$SCRIPT'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[→999%]"* ]]
}

@test "NO_COLOR strips ANSI from the forecast bracket too" {
    # NO_COLOR is already set in setup(). With a usable reset_ts the bracket renders.
    local now reset esc
    now=$(date +%s)
    reset=$((now + 7200))
    run bash -c "echo '{\"cwd\":\"/tmp\",\"rate_limits\":{\"five_hour\":{\"used_percentage\":45,\"resets_at\":$reset}}}' | bash '$SCRIPT'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[→75%]"* ]]
    esc=$(printf '\033')
    [[ "$output" != *"$esc"* ]]
}

# --- per-bar visibility toggles ----------------------------------------

@test "context bar glyph renders by default" {
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"context_window\":{\"used_percentage\":34,\"context_window_size\":200000}}" | bash "'"$SCRIPT"'"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"#"* ]]
    [[ "$output" == *"34%"* ]]
}

@test "CLAUDE_STATUSLINE_BAR_CONTEXT=0 hides the context bar glyph but keeps the percentage" {
    export CLAUDE_STATUSLINE_BAR_CONTEXT=0
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"context_window\":{\"used_percentage\":34,\"context_window_size\":200000}}" | bash "'"$SCRIPT"'"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"34%"* ]]
    [[ "$output" == *"68k/200k"* ]]
    [[ "$output" != *"#"* ]]
}

@test "CLAUDE_STATUSLINE_BAR_5H=0 hides the 5h bar glyph but keeps the percentage" {
    export CLAUDE_STATUSLINE_BAR_5H=0
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"rate_limits\":{\"five_hour\":{\"used_percentage\":45}}}" | bash "'"$SCRIPT"'"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"45%"* ]]
    [[ "$output" != *"#"* ]]
}

@test "CLAUDE_STATUSLINE_BAR_WEEKLY=0 hides the weekly bar glyph but keeps the percentage" {
    export CLAUDE_STATUSLINE_BAR_WEEKLY=0
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"rate_limits\":{\"seven_day\":{\"used_percentage\":62}}}" | bash "'"$SCRIPT"'"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"62%"* ]]
    [[ "$output" != *"#"* ]]
}

@test "BAR_5H=0 leaves the weekly bar rendered (toggles are independent)" {
    export CLAUDE_STATUSLINE_BAR_5H=0
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"rate_limits\":{\"five_hour\":{\"used_percentage\":45},\"seven_day\":{\"used_percentage\":62}}}" | bash "'"$SCRIPT"'"'
    [ "$status" -eq 0 ]
    # Line 3 is "<5h segment> · <weekly segment>". Take the last output line,
    # then split it on " · " so line-1 content can never affect the split.
    line3="${output##*$'\n'}"
    five_part="${line3%% · *}"
    week_part="${line3#* · }"
    # 5h segment lost its glyph...
    [[ "$five_part" != *"#"* ]]
    # ...but the weekly segment still has one.
    [[ "$week_part" == *"#"* ]]
    [[ "$output" == *"45%"* ]]
    [[ "$output" == *"62%"* ]]
}
