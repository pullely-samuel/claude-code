# Claude Code Documentation (Local Copy)

This folder contains a local copy of the official [Claude Code documentation](https://code.claude.com/docs/en/overview) for faster access by Claude Code and other LLMs.

## Why Local Docs?

LLMs can access local markdown files much faster than fetching from the web. By keeping documentation locally, Claude Code can use its `Read` tool to quickly reference docs without network latency.

## Contents

- `index.md` - Documentation index with links to all doc files
- `*.md` - Individual documentation pages
- `scripts/fetch-docs.sh` - Script to update documentation

## Updating Documentation

To fetch the latest documentation:

```bash
./scripts/fetch-docs.sh
```

The script will:
1. Remove outdated documentation files (preserving this README)
2. Fetch the latest docs from [llms.txt](https://code.claude.com/docs/llms.txt)
3. Download all markdown files
4. Create an updated `index.md` with local paths

### Script Options

```bash
./scripts/fetch-docs.sh --help      # Show help
./scripts/fetch-docs.sh --dry-run   # Preview changes without downloading
./scripts/fetch-docs.sh --quiet     # Suppress progress output
```

### After Updating

```bash
git add -A docs/
git commit -m "Update Claude Code documentation"
git push
```

## Syncing with Upstream

This is a fork of [anthropics/claude-code](https://github.com/anthropics/claude-code). To sync with upstream:

```bash
git fetch upstream
git merge upstream/main
```

The `docs/` folder won't conflict since it doesn't exist in the upstream repository.

## Source

Documentation is fetched from: https://code.claude.com/docs/llms.txt
