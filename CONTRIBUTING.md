# Contributing

Contributions are welcome. Please open an issue to discuss larger changes before submitting a PR.

## Requirements

- POSIX `sh` only -- no bashisms (`[[ ]]`, arrays, `local`, process substitution)
- `jq` for JSON parsing
- A 256-color terminal for visual testing

## Development

Run the test harness after any change:

    sh test.sh full

Test all scenarios and themes:

    for s in minimal mid full critical; do sh test.sh "$s"; done
    for t in catppuccin-mocha bluloco-dark dracula nord; do sh test.sh mid "$t"; done

Syntax-check all files:

    find . -name '*.sh' -print0 | xargs -0 -I{} sh -c 'sh -n "$1" || echo "FAIL: $1"' _ {}

## Adding a Segment

1. Create `segments/my-segment.sh` with a `segment_my_segment()` function
2. Set all `_seg_*` metadata variables, return 0 to render or 1 to skip
3. Add `segment_my_segment` to `SL_SEGMENTS` in `main.sh`
4. Run syntax check and test harness

See `CLAUDE.md` for the full segment contract and variable naming conventions.

## Adding a Theme

1. Create `themes/my-theme.sh` with all 12 `PALETTE_*` variables
2. Optionally override specific `C_*` tokens
3. Run syntax check: `sh -n themes/my-theme.sh`
4. Test: `sh test.sh full my-theme`

## Style

- Prefix function-local variables with `_xx_` (2-3 letter function abbreviation)
- Segments must NOT embed raw ANSI escapes in `_seg_content`
- Use `${VAR:-default}` pattern for overridable values
- Use `$(( ))` for arithmetic
