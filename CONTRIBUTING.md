# Contributing

Contributions are welcome! Please open an issue to discuss larger changes before submitting a PR.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Commit Conventions](#commit-conventions)
- [Pull Request Guidelines](#pull-request-guidelines)
- [Continuous Integration](#continuous-integration)
- [Adding a Segment](#adding-a-segment)
- [Adding a Theme](#adding-a-theme)
  - [Creating from scratch](#creating-a-theme-from-scratch)
  - [Porting a terminal theme](#porting-an-existing-terminal-theme)
  - [Semantic tokens reference](#available-semantic-tokens)
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
sh test/run.sh --scenario full    # verify everything works
```

---

## Development Workflow

1. **Fork** the repository and create a feature branch
2. **Make changes** - keep them focused on a single concern
3. **Verify** syntax and rendering:

```sh
# Syntax check all files
find . -name '*.sh' -print0 | xargs -0 -I{} sh -c 'sh -n "$1" || echo "FAIL: $1"' _ {}

# Check for bashisms
grep -rn '\[\[' --include='*.sh' .
grep -rn '^[[:space:]]*local ' --include='*.sh' .

# Run all test scenarios (visual)
sh test/run.sh

# CI assertions (all scenarios x tiers x themes)
sh test/run.sh --check
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

**Scopes:** Use the file or area name: `cache`, `model`, `context`, `nord`, `lib`, etc.

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
- [ ] `sh test/run.sh --check` passes (all 48 combinations)
- [ ] Commit messages follow conventional commits format

**Scope:** Keep PRs focused. One segment, one theme, or one fix per PR. If a change touches multiple concerns, split it.

**Large changes:** Open an issue first to discuss the approach. This avoids wasted effort on PRs that don't align with the project direction.

---

## Continuous Integration

PRs are checked automatically by GitHub Actions:

1. **Lint:** syntax check (`sh -n`) + bashism scan on all `.sh` files
2. **Test:** `sh test/run.sh --check` under dash, bash, and zsh

CI must pass before merging. You can run the same checks locally:

```sh
sh test/run.sh --check
```

---

## Adding a Segment

1. Create `lib/segments/my-segment.sh` with a `segment_my_segment()` function
2. Set all `_seg_*` metadata variables, return 0 to render or 1 to skip
3. Add `segment_my_segment` to `SL_SEGMENTS` in `main.sh` at the desired position
4. Run syntax check: `sh -n lib/segments/my-segment.sh`
5. Run test harness: `sh test/run.sh --scenario full`

See [`CLAUDE.md`](CLAUDE.md) for the full segment contract, metadata variable reference, and variable naming conventions.

---

## Adding a Theme

### How the theme system works

Themes only need to define 12 `PALETTE_*` base colors. The derivation layer (`lib/derive.sh`) automatically maps those into ~30 semantic tokens (`C_*`) that control every color in the status line: model backgrounds, context gauge states, duration escalation, git indicators, and more.

You can override any derived token directly in your theme file for fine-tuning. The derivation uses `${VAR:-default}`, so anything you set before `derive.sh` runs takes priority.

### Creating a theme from scratch

1. Create `lib/themes/my-theme.sh` with all 12 palette variables:

```sh
#!/bin/sh
# themes/my-theme.sh -- My custom palette
# Tip: use a 256-color chart to find values
# https://www.ditig.com/256-colors-cheat-sheet

PALETTE_BG=234          # terminal background
PALETTE_FG=188          # default text
PALETTE_BG_ALT=236      # muted/secondary segment background
PALETTE_BG_DIM=233      # recessed segment background (duration in full tier)
PALETTE_BLUE=111         # Sonnet model background
PALETTE_GOLD=223         # Opus model background
PALETTE_GREEN=151        # healthy context, lines added
PALETTE_CYAN=158         # Haiku model background
PALETTE_RED=211          # critical context, lines removed
PALETTE_ORANGE=216       # filling context, high duration
PALETTE_MAGENTA=183      # worktree indicator
PALETTE_DIM=243          # subdued text (tertiary segments, separators)
```

2. (Optional) Override specific derived tokens for fine-tuning:

```sh
# Make Sonnet a deeper blue to reduce glare
C_SONNET_BG=69

# Use a green-tinted dark BG for the healthy context gauge
C_CTX_HEALTHY_BG=22

# Use dark red for filling/critical context gauge backgrounds
C_CTX_FILLING_BG=52
C_CTX_SOON_BG=52
C_CTX_CRIT_BG=52
```

3. Test it:

```sh
sh test/run.sh --scenario full --theme my-theme
sh test/run.sh --scenario critical --theme my-theme   # check context gauge colors
```

### Porting an existing terminal theme

If you already use a terminal color scheme (e.g., Tokyo Night, Gruvbox, Solarized, One Dark), you can port it:

1. **Find the hex values.** Most themes publish their palette on GitHub. You need: background, foreground, and the 8 accent colors (red, green, yellow, blue, magenta, cyan, plus an orange and a dim/gray).

2. **Convert hex to 256-color.** Use a [256-color chart](https://www.ditig.com/256-colors-cheat-sheet) or run this in your terminal to find the closest match:

```sh
# Show 256-color palette with numbers
for i in $(seq 0 255); do printf '\033[48;5;%dm %3d \033[0m' "$i" "$i"; [ $(( (i + 1) % 16 )) -eq 0 ] && printf '\n'; done
```

3. **Map the colors.** Here's how palette variables map to typical terminal theme roles:

| Palette variable | Terminal theme role |
|-----------------|---------------------|
| `PALETTE_BG` | Background |
| `PALETTE_FG` | Foreground / text |
| `PALETTE_BG_ALT` | Selection background, or slightly lighter than BG |
| `PALETTE_BG_DIM` | Slightly darker than BG (or same as BG for flat themes) |
| `PALETTE_BLUE` | Blue accent |
| `PALETTE_GOLD` | Yellow accent |
| `PALETTE_GREEN` | Green accent |
| `PALETTE_CYAN` | Cyan accent |
| `PALETTE_RED` | Red accent |
| `PALETTE_ORANGE` | Orange accent (if the theme has one, otherwise use a warm yellow) |
| `PALETTE_MAGENTA` | Magenta/purple accent |
| `PALETTE_DIM` | Comment color / dimmed text |

4. **Check contrast.** The most important thing is that primary segment text is readable on its background. Test all 4 scenarios:

```sh
for s in minimal mid full critical; do sh test/run.sh --scenario "$s" --theme my-theme; done
```

5. **Fine-tune.** Common adjustments when porting:
   - If the Opus (gold) or Haiku (cyan) model segment text is hard to read, override `C_OPUS_FG` or `C_HAIKU_FG`
   - If context gauge backgrounds blend into the status line, override `C_CTX_HEALTHY_BG`, `C_CTX_FILLING_BG`, etc.
   - If the dim text is too invisible, bump `PALETTE_DIM` to a lighter gray

### Available semantic tokens

All tokens can be overridden in your theme file. Set them before `derive.sh` runs (the theme file is sourced first).

| Token | Default | Purpose |
|-------|---------|---------|
| `C_OPUS_BG/FG` | gold/bg | Opus model segment |
| `C_SONNET_BG/FG` | blue/white | Sonnet model segment |
| `C_HAIKU_BG/FG` | cyan/bg | Haiku model segment |
| `C_BASE_BG/FG` | bg/fg | Base UI colors |
| `C_MUTED_BG` | bg_alt | Secondary/tertiary segment background |
| `C_DIM_BG` | bg_dim | Recessed segment background |
| `C_DIM` | dim | Subdued text, separators |
| `C_CTX_HEALTHY_BG/FG` | dark green/green | Context gauge 0-49% |
| `C_CTX_WARMING_BG/FG` | bg/gold | Context gauge 50-69% |
| `C_CTX_FILLING_BG/FG` | dark red/orange | Context gauge 70-84% |
| `C_CTX_SOON_BG/FG` | dark red/red | Context gauge 85-94% |
| `C_CTX_CRIT_BG/FG` | dark red/red | Context gauge 95%+ |
| `C_DUR_LOW/MED/HIGH/CRIT` | dim/fg/orange/red | Duration color escalation |
| `C_LINES_ADD/DEL/ZERO` | green/red/gold | Lines changed indicator |
| `C_WORKTREE_FG` | magenta | Worktree segment text |
| `C_CACHE_GOOD/POOR` | dim/orange | Cache hit ratio |

### Validation

After creating your theme, verify all tokens resolve:

```sh
CLAUDE_STATUSLINE_THEME=my-theme SL_DIR=. SL_LIB=./lib sh -c '. ./lib/theme.sh
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

Segments must set `_seg_content` as **plain text** - no ANSI escapes. The orchestrator handles all color and formatting. Use `_seg_link_url` for OSC 8 hyperlinks.

See [`CLAUDE.md`](CLAUDE.md) for the complete architecture reference.
