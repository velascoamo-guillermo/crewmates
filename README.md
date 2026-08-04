# crewmates

Harness-agnostic agent definitions + deterministic scripts for the GitHub ticket
loop. One source of truth, thin adapters per tool (Claude Code, opencode, ...).

## Philosophy

1. **Deterministic step → script, judgment step → model.** Creating a PR when
   title/body are already decided is `gh pr create`, not an LLM call. Writing
   the PR body from a diff is judgment → cheapest capable model.
2. **The crewmate is the prompt, not the harness config.** `PROMPT.md` holds the
   role, workflow, and output contract — model-agnostic, tool-agnostic. Model
   choice and tool restrictions live in `meta.json` per harness and get baked
   into generated adapters.

## Layout

```
crewmates/<name>/PROMPT.md   # role + contract, no frontmatter
crewmates/<name>/meta.json   # description + per-harness config
scripts/gh/*.sh              # deterministic gh helpers (zero tokens)
scripts/generate-adapters.ts # emits per-harness agent files
```

## Crewmates

| Name | Model tier | Role |
|---|---|---|
| `implementer` | sonnet | One ticket from a brief file, strict TDD, PR + green CI |
| `task-reviewer` | opus, read-only | Adversarial spec + quality review, file:line evidence |
| `gh-publisher` | haiku | Writes issue/PR content, publishes via scripts |

## Setup on a new machine

```bash
git clone git@github.com:velascoamo-guillermo/crewmates.git
cd crewmates && ./setup.sh
```

Requires `bun` and an authenticated `gh`. The script generates adapters and adds
`CREWMATES_HOME` to `~/.zshrc` (idempotent).

## Generate adapters

```bash
bun run generate            # ~/.claude/agents + ~/.config/opencode/agent
bun run generate:dry        # preview targets
bun scripts/generate-adapters.ts --only gh-publisher
bun scripts/generate-adapters.ts --claude-out <dir> --opencode-out <dir>
```

Re-run after editing any `PROMPT.md` or `meta.json`. Generated files are build
artifacts — edit the source here, never the adapter.

## gh scripts

All assume `gh` is authenticated. Set `CREWMATES_HOME` so agents can find them:

```bash
# in ~/.zshrc
export CREWMATES_HOME="$HOME/Documents/Projects/crewmates"
```

| Script | Does |
|---|---|
| `next-ticket.sh [--repo o/r]` | Lowest open `ticket` issue with all `Depends on: #N` closed → `NUMBER\tTITLE` |
| `issue-create.sh --title --body-file [--label]` | Create issue, print URL |
| `pr-create.sh --title --body-file [--base] [--draft]` | Push branch (never main, never force), open PR |
| `ci-wait.sh [pr]` | Block until checks finish; exit 0 = green |
| `pr-merge.sh <pr> [--issue N]` | Squash-merge, delete branch, close issue |
| `board-move.sh --owner --project --issue --status` | Move card on Projects v2 board |

## Skills

`skills/<name>/SKILL.md` — reusable knowledge, routed on demand: only the
frontmatter `description` sits in context; the body loads when relevant.
`setup.sh` symlinks each one into `~/.claude/skills/` (machine-global, every
project). SKILL.md is an open format — same files work in other harnesses that
adopt it.

Writing rule: the `description` is the router. Write it as trigger conditions
("Use when adding haptic feedback in RN...") — a vague summary means the skill
never loads. Keep bodies thin: preferences, pointers, and guardrails; link docs
instead of pasting API details that rot.

## Adding a crewmate

1. `mkdir crewmates/<name>`, write `PROMPT.md` (role, input, workflow, output
   contract, hard rules) and `meta.json`.
2. Keep the prompt model-agnostic: explicit contracts, no reliance on the model
   inferring unstated conventions — it must work on a cheap model.
3. `bun run generate`.

Keep the roster small: a crewmate earns its place only if the role repeats with
a fixed contract, needs tool restrictions, or runs on a different model tier.
Everything else is a general-purpose agent with a good brief.
