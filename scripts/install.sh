#!/usr/bin/env bash
#
# claude-statusline installer
#
#   curl -fsSL https://raw.githubusercontent.com/codename-cn/claude-statusline/main/scripts/install.sh | bash
#
# Downloads statusline.sh to ~/.claude/statusline.sh and patches
# ~/.claude/settings.json with the statusLine entry — backing up any
# pre-existing statusline configuration first and confirming before
# overwrite.
#
# Environment:
#   CLAUDE_STATUSLINE_REF=main    Git ref to install from (branch, tag, or SHA).
#   CLAUDE_STATUSLINE_FORCE=1     Skip the confirmation prompt when an
#                                 existing statusLine entry is found.

set -euo pipefail

REPO_SLUG="codename-cn/claude-statusline"
REF="${CLAUDE_STATUSLINE_REF:-main}"
RAW_BASE="https://raw.githubusercontent.com/${REPO_SLUG}/${REF}"

CLAUDE_DIR="${HOME}/.claude"
SCRIPT_DEST="${CLAUDE_DIR}/statusline.sh"
SETTINGS="${CLAUDE_DIR}/settings.json"
DESIRED_COMMAND="bash ${SCRIPT_DEST}"

die() {
    printf 'claude-statusline: %s\n' "$1" >&2
    exit 1
}

info() {
    printf '==> %s\n' "$1"
}

warn() {
    printf '!!  %s\n' "$1" >&2
}

# ---------------------------------------------------------------------------
# Preflight.
# ---------------------------------------------------------------------------
command -v bash > /dev/null 2>&1 || die "bash not found on PATH"
command -v jq > /dev/null 2>&1 || die "jq not found on PATH — install it first (e.g. 'sudo apt install jq' or 'brew install jq')"
command -v curl > /dev/null 2>&1 || die "curl not found on PATH"

if [ ! -d "$CLAUDE_DIR" ]; then
    info "Creating ${CLAUDE_DIR}"
    mkdir -p "$CLAUDE_DIR"
    chmod 700 "$CLAUDE_DIR"
fi

# ---------------------------------------------------------------------------
# Download statusline.sh atomically.
# ---------------------------------------------------------------------------
info "Downloading statusline.sh from ${REPO_SLUG}@${REF}"
tmp=$(mktemp "${SCRIPT_DEST}.XXXXXX")
trap 'rm -f "$tmp"' EXIT
if ! curl -fsSL "${RAW_BASE}/statusline.sh" -o "$tmp"; then
    die "download failed — is the ref '${REF}' valid?"
fi
# Sanity-check: the first line should start with a bash shebang.
head -n1 "$tmp" | grep -q '^#!.*bash' || die "downloaded file does not look like a bash script"
chmod +x "$tmp"
mv "$tmp" "$SCRIPT_DEST"
trap - EXIT
info "Installed ${SCRIPT_DEST}"

# ---------------------------------------------------------------------------
# Patch settings.json with the statusLine entry.
# ---------------------------------------------------------------------------
existing_cmd=""
if [ -f "$SETTINGS" ]; then
    existing_cmd=$(jq -r '.statusLine.command // empty' "$SETTINGS" 2> /dev/null || true)
fi

if [ -n "$existing_cmd" ] && [ "$existing_cmd" != "$DESIRED_COMMAND" ]; then
    warn "settings.json already has a different statusLine.command:"
    warn "    current:  ${existing_cmd}"
    warn "    desired:  ${DESIRED_COMMAND}"
    if [ "${CLAUDE_STATUSLINE_FORCE:-0}" != "1" ]; then
        if [ -t 0 ]; then
            printf 'Overwrite it? [y/N] '
            read -r reply
        else
            # stdin is piped (curl | bash); we cannot prompt interactively.
            reply=""
        fi
        case "$reply" in
            y | Y | yes | YES) ;;
            *)
                warn "Aborted. Your settings.json was not modified."
                warn "Re-run with CLAUDE_STATUSLINE_FORCE=1 to overwrite non-interactively,"
                warn "or edit ${SETTINGS} manually to set statusLine.command to:"
                warn "    ${DESIRED_COMMAND}"
                exit 0
                ;;
        esac
    fi
    backup="${SETTINGS}.bak-$(date +%Y%m%d-%H%M%S)"
    cp -p "$SETTINGS" "$backup"
    info "Backed up previous settings.json to ${backup}"
fi

# Write new settings.json atomically via jq.
if [ -f "$SETTINGS" ]; then
    tmp=$(mktemp "${SETTINGS}.XXXXXX")
    jq --arg cmd "$DESIRED_COMMAND" \
        '.statusLine = {"type": "command", "command": $cmd}' \
        "$SETTINGS" > "$tmp"
    mv "$tmp" "$SETTINGS"
else
    cat > "$SETTINGS" << EOF
{
  "statusLine": {
    "type": "command",
    "command": "${DESIRED_COMMAND}"
  }
}
EOF
fi
chmod 600 "$SETTINGS"
info "Patched ${SETTINGS}"

# ---------------------------------------------------------------------------
# Smoke test.
# ---------------------------------------------------------------------------
info "Running a synthetic-payload smoke test…"
probe=$(printf '%s' '{"cwd":"/tmp","version":"probe","model":{"display_name":"smoke-test"}}' |
    "$SCRIPT_DEST" 2>&1 || true)
if [ -z "$probe" ]; then
    warn "Smoke test produced no output. Check that jq is on PATH for Claude Code's shell."
else
    printf '%s\n' "$probe"
fi

cat << 'EOT'

✔ claude-statusline installed.

Next steps:
  1. Open a new Claude Code session (or restart the one you have).
  2. The three-line statusline will appear at the bottom of the prompt.
  3. Customize via env vars — see:
     https://github.com/codename-cn/claude-statusline#configuration
EOT
