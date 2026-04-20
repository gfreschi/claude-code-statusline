## What

<!-- Brief description of what this PR does -->

## Why

<!-- Motivation: what problem does it solve or what does it improve? -->

## How to test

<!-- Steps to verify the change works -->

```sh
sh test/run.sh --check
```

## Checklist

- [ ] `sh -n` passes on all `.sh` files
- [ ] No bashisms (`[[ ]]`, `local`, `declare`, arrays, process substitution)
- [ ] `sh test/run.sh --check` passes (100 combinations)
- [ ] Tested visually with at least one theme
- [ ] Conventional commit messages
