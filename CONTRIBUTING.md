# Contributing

Issues and PRs welcome — the repo is intentionally small, and every addition earns its place.

## Before opening a PR

Run the same three checks CI runs:

```sh
shellcheck statusline.sh scripts/install.sh
shfmt -d -i 4 -ci -sr statusline.sh scripts/install.sh
bats tests/
```

A PR that fails any of them will not merge.

## Commit style

Short, imperative present-tense subject line (≤ 70 chars). Body optional. Reference the issue in the body, not the subject.

```
Add CLAUDE_STATUSLINE_SHOW_TZ env var

Closes #42.
```

Do not add AI-attribution trailers (`Co-Authored-By: …`) to commit messages.

## Design rules

1. **Single-file distribution is a feature.** Keep `statusline.sh` under ~500 lines. If a change pushes it meaningfully over, open an issue first to discuss splitting.
2. **Zero runtime dependencies beyond `bash`, `jq`, `git`, `date`.** Do not add a `curl`/`python`/`awk`-gawk dependency to the runtime path. Installer and CI may use more, script itself may not.
3. **Portable across GNU + BSD `date`.** Only use format specifiers that exist on both. When in doubt, grep [`_date_from_epoch`](./statusline.sh) for the existing pattern and reuse it.
4. **No private data.** No hardcoded paths, emails, organization names, project names. CI greps for common leaks.
5. **Every new env var:**
   - Add to the header docstring in `statusline.sh`.
   - Add to the Configuration table in `README.md`.
   - Add a bats test in `tests/`.
6. **Every new output segment:**
   - Add to the "What it shows" table in `README.md`.
   - Add a bats test in `tests/` that exercises it end-to-end.

## Adding a test

Put it in `tests/test_statusline.bats`. The existing file is a good template. Tests run with `NO_COLOR=1` so ANSI escapes don't muddy the assertions.

## Performance

The script runs on every prompt refresh. We target ≤ 60 ms per render on a modern Linux box.

If you're adding logic in the hot path, benchmark before and after:

```sh
PAYLOAD='{"cwd":"/tmp","version":"x","model":{"display_name":"m"}}'
time for i in $(seq 1 30); do printf '%s' "$PAYLOAD" | ./statusline.sh > /dev/null; done
```

Subshells (`$(…)`), external commands inside loops, and per-field `jq` calls are the usual regression sources. Prefer bash builtins and inlined math.
