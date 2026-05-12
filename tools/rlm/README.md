# rlm

The unified write interface for the AI Agent-Team RLM (knowledge base).

**Source of truth**: [`.rlm/contracts/rlm-cli.md`](../../.rlm/contracts/rlm-cli.md) — this CLI implements that contract. When this code disagrees with the contract, fix the code (or open a PR to amend the contract).

## Install (development)

```sh
cd tools/rlm
uv sync
uv run rlm --help
```

Or install the script entry point on PATH:

```sh
uv pip install -e .
rlm --help
```

## Required env

Every write command requires:

```sh
export RLM_AGENT_ROLE=worker  # one of: hermes / hermes-design / worker / dispatch /
                              #         whitebox-validator / blackbox-validator /
                              #         arbiter / supervision
```

Optional (highly recommended for audit chains):

```sh
export RLM_AGENT_INVOCATION=$(uuidgen)   # UUID per LLM invocation
export RLM_SKILL_NAME=business-model-probe   # active skill name
```

Plus, depending on which subcommands you call:

```sh
export GH_TOKEN=...     # GitHub personal access token (gh CLI also uses this)
export REDIS_URL=redis://localhost:6379/0   # optional; JSONL-only mode if unset
```

## Subcommands

Run `rlm --help` to see all 17. Each is documented in `.rlm/contracts/rlm-cli.md` § Subcommand reference.

Routing summary:

- **PR-routed** (decisions): `propose-adr`, `propose-context-change`, `add-contract`
- **Direct-commit** (observations): `append-fact`, `supersede-fact`, `append-business-model`, `append-deployment-constraints`
- **Issue-routed** (workflow): `commit-spec`, `confirm-spec`, `commit-workpackage`, `approve-workpackage`, `record-signal`, `mark-superseded`, `mark-in-progress`, `mark-delivered`, `enqueue-message`
- **PR create from Worker**: `open-pr`

## Output

Default: human-readable to stdout.

`--json` mode: single JSON object on one line to stdout.

Errors: single JSON object on one line to stderr (regardless of `--json`).

## Exit codes

Per contract § Error model:

| Code | Name |
|---|---|
| 0 | ok |
| 1 | usage-error |
| 2 | validation-error |
| 3 | permission-error |
| 4 | no-rlm-root |
| 5 | state-write-error |
| 6 | precondition-failed |
| 7 | conflict |
| 8 | external-service-down |
| 99 | internal-error |

## Development

```sh
uv run pytest                # tests
uv run ruff check .          # lint
uv run ruff format .         # format
uv run mypy rlm              # type-check
```

## Status

v0.1.0 — scaffolded; subcommand bodies stubbed. Filling in per contract section by section.

Track progress: `.rlm/v2-todo.md` § A1.
