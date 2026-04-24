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
    unset CLAUDE_STATUSLINE_PEAKTIME_HIDDEN
    unset CLAUDE_CODE_EFFORT_LEVEL
    unset CLAUDE_STATUSLINE_SHOW_TZ
    unset CLAUDE_STATUSLINE_FORCE_12H
    unset CLAUDE_STATUSLINE_FORCE_24H
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

@test "demo mode renders PEAK TIME label" {
    export CLAUDE_STATUSLINE_DEMO=1
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"model\":{\"display_name\":\"M\"}}" | bash "'"$SCRIPT"'"'
    [[ "$output" == *"PEAK TIME"* ]]
}

@test "PEAKTIME_HIDDEN suppresses the segment even in demo mode" {
    export CLAUDE_STATUSLINE_DEMO=1
    export CLAUDE_STATUSLINE_PEAKTIME_HIDDEN=1
    run bash -c 'echo "{\"cwd\":\"/tmp\",\"model\":{\"display_name\":\"M\"}}" | bash "'"$SCRIPT"'"'
    [[ "$output" != *"PEAK TIME"* ]]
}

# --- separators ---------------------------------------------------------

@test "line 1 uses ' · ' between cwd and PEAK TIME in demo mode" {
    export CLAUDE_STATUSLINE_DEMO=1
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
