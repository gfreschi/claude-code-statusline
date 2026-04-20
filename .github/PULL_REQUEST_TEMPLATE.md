## Summary

<!-- One or two sentences on what the PR does and why it matters. -->

## Changes

<!-- Bulleted list of the concrete changes. Group by file/area when helpful. -->

-
-

## Screenshots / GIFs

<!-- Required for anything that changes the rendered status line. -->
<!-- Regenerate with: vhs images/<tape>.tape (see CONTRIBUTING.md). -->

## How to test

```sh
sh test/run.sh --check                 # 101 combinations, sh
sh test/run.sh --check --shell dash    # 101 combinations, dash
sh test/run.sh --check --shell bash    # 101 combinations, bash
sh test/run.sh --check --shell zsh     # 101 combinations, zsh
sh test/run.sh --bench                 # regression guard: 100 ms macOS / 60 ms Linux
```

Visual spot-check on at least one theme + tier width you touched:

```sh
COLUMNS=140 sh main.sh < test/fixtures/full.json
```

## Breaking changes

<!-- "None" or: describe user-visible changes that require action. -->

None.

## Related

<!-- Link issues/discussions this PR closes or references. Use "Closes #N" to auto-close. -->

## Checklist

- [ ] `sh -n` passes on every modified `.sh` file
- [ ] No bashisms (`[[ ]]`, `local`, `declare`, arrays, process substitution)
- [ ] `sh test/run.sh --check` passes on sh / dash / bash / zsh (**101 / 101** each)
- [ ] `sh test/run.sh --bench` still under the macOS (100 ms) / Linux (60 ms) threshold
- [ ] New env vars / segments / themes documented in `docs/CONFIG.md`, `README.md`, and `CLAUDE.md` where applicable
- [ ] `CHANGELOG.md` has an `[Unreleased]` entry (or the change is purely internal / refactor-only)
- [ ] GIFs under `images/` are refreshed if the visual output changed
- [ ] Commits follow Conventional Commits (`feat:`, `fix:`, `perf:`, `docs:`, `test:`, `chore:`, ...)
