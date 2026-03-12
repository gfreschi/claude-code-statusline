# Contributing

Contributions are welcome! Please open an issue to discuss larger changes before submitting a PR.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Commit Conventions](#commit-conventions)
- [Pull Request Guidelines](#pull-request-guidelines)
- [Adding a Segment](#adding-a-segment)
- [Adding a Theme](#adding-a-theme)
- [Code Style](#code-style)

---

## Getting Started

### Prerequisites

- POSIX-compatible shell (`sh`, `dash`, `bash`, `zsh`)
- [`jq`](https://jqlang.github.io/jq/) for JSON parsing
- A 256-color terminal for visual testing
- [Nerd Font](https://www.nerdfonts.com/) (optional, for icon testing)

### Setup

```sh
git clone https://github.com/gfreschi/claude-code-statusline.git
cd claude-code-statusline
sh test.sh full    # verify everything works
```

---

## Development Workflow

1. **Fork** the repository and create a feature branch
2. **Make changes** -- keep them focused on a single concern
3. **Verify** syntax and rendering:

```sh
# Syntax check all files
find . -name '*.sh' -print0 | xargs -0 -I{} sh -c 'sh -n "$1" || echo "FAIL: $1"' _ {}

# Check for bashisms
grep -rn '\[\[' --include='*.sh' .
grep -rn '^[[:space:]]*local ' --include='*.sh' .

# Run all test scenarios
for s in minimal mid full critical; do sh test.sh "$s"; done

# Run all themes
for t in catppuccin-mocha bluloco-dark dracula nord; do sh test.sh mid "$t"; done
```

4. **Commit** using [conventional commits](#commit-conventions)
5. **Open a PR** with a clear description of what and why

---

## Commit Conventions

This project uses [Conventional Commits](https://www.conventionalcommits.org/).

**Format:** `type(scope): description`

| Type | When to use |
|------|------------|
| `feat` | New segment, theme, or capability |
| `fix` | Bug fix |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `docs` | Documentation only |
| `test` | Test harness changes |
| `chore` | Maintenance, tooling, CI |
| `perf` | Performance improvement |

**Scopes:** Use the file or area name -- `cache`, `model`, `context`, `nord`, `lib`, etc.

**Examples:**

```
feat(segments): add cost-per-hour segment
fix(cache): handle branch names with special characters
refactor(context): deduplicate dot-building across tiers
docs: update theme creation guide
```

---

## Pull Request Guidelines

Before submitting:

- [ ] All `.sh` files pass `sh -n` syntax check
- [ ] No bashisms (`[[ ]]`, `local`, `declare`, arrays, process substitution)
- [ ] All 4 test scenarios render correctly across all 3 tiers
- [ ] All 4 bundled themes render correctly
- [ ] Commit messages follow conventional commits format

**Scope:** Keep PRs focused. One segment, one theme, or one fix per PR. If a change touches multiple concerns, split it.

**Large changes:** Open an issue first to discuss the approach. This avoids wasted effort on PRs that don't align with the project direction.

---

## Adding a Segment

1. Create `segments/my-segment.sh` with a `segment_my_segment()` function
2. Set all `_seg_*` metadata variables, return 0 to render or 1 to skip
3. Add `segment_my_segment` to `SL_SEGMENTS` in `main.sh` at the desired position
4. Run syntax check: `sh -n segments/my-segment.sh`
5. Run test harness: `sh test.sh full`

See [`CLAUDE.md`](CLAUDE.md) for the full segment contract, metadata variable reference, and variable naming conventions.

---

## Adding a Theme

1. Create `themes/my-theme.sh` with all 12 `PALETTE_*` variables
2. Optionally override specific `C_*` tokens for fine-tuning contrast
3. Run syntax check: `sh -n themes/my-theme.sh`
4. Test visually: `sh test.sh full my-theme`
5. Validate all tokens are defined:

```sh
CLAUDE_STATUSLINE_THEME=my-theme SL_DIR=. sh -c '. ./theme.sh
  for var in C_OPUS_BG C_OPUS_FG C_SONNET_BG C_SONNET_FG C_HAIKU_BG C_HAIKU_FG \
    C_BASE_BG C_BASE_FG C_MUTED_BG C_DIM_BG C_DIM C_WHITE \
    C_CTX_HEALTHY_BG C_CTX_HEALTHY_FG C_CTX_WARMING_BG C_CTX_WARMING_FG \
    C_CTX_FILLING_BG C_CTX_FILLING_FG C_CTX_SOON_BG C_CTX_SOON_FG \
    C_CTX_CRIT_BG C_CTX_CRIT_FG C_DUR_LOW C_DUR_MED C_DUR_HIGH C_DUR_CRIT \
    C_LINES_ADD C_LINES_DEL C_LINES_ZERO C_WORKTREE_FG C_CACHE_GOOD C_CACHE_POOR; do
    eval "val=\$$var"; [ -z "$val" ] && echo "MISSING: $var"
  done && echo "ALL OK"'
```

---

## Code Style

**POSIX sh is mandatory.** No bashisms, no exceptions.

| Rule | Details |
|------|---------|
| **No `[[ ]]`** | Use `[ ]` with proper quoting |
| **No `local`** | Prefix variables with `_xx_` (2-3 letter function abbreviation) |
| **No arrays** | Use space-separated strings or positional parameters |
| **No process substitution** | Use pipes or temp files |
| **Arithmetic** | `$(( ))` only, not `let` or `(( ))` |
| **Error suppression** | `2>/dev/null` for commands that may fail on missing input |
| **Overridable defaults** | `${VAR:-default}` in `derive.sh` so themes can override tokens |
| **Globbing** | `set -f` is active in `main.sh`; re-enable with `set +f` only when needed |

Segments must set `_seg_content` as **plain text** -- no ANSI escapes. The orchestrator handles all color and formatting. Use `_seg_link_url` for OSC 8 hyperlinks.

See [`CLAUDE.md`](CLAUDE.md) for the complete architecture reference.
