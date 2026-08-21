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
| `planner` | opus, read-only | Spec → file-level plan, per-task TDD strategy, dependency order |
| `implementer` | sonnet | One ticket from a brief file, strict TDD, PR + green CI |
| `task-reviewer` | opus, read-only | Adversarial spec + quality review, file:line evidence |
| `gh-publisher` | haiku | Writes issue/PR/MR content from `templates/`, publishes via gh or glab scripts |
| `ui-qa` | sonnet | Argent UI verification loops; screenshots stay in its context, returns <20-line verdicts |

## Setup on a new machine

```bash
git clone git@github.com:velascoamo-guillermo/crewmates.git
cd crewmates && ./setup.sh
```

Requires `bun` and an authenticated `gh`. The script generates adapters and adds
`CREWMATES_HOME` to `~/.zshrc` (idempotent).

Health check anytime: `./doctor.sh` — verifies tools, auth, skill symlinks, and
flags stale adapters (source edited without re-running `bun run generate`).
CI runs shellcheck + generator verification on every push.

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
| `ensure-labels.sh [--repo o/r]` | Idempotently create workflow labels (`ticket`, `blocked`). Run once per repo |
| `issue-create.sh --title --body-file [--label] [--assignee @me]` | Create issue, print URL. Blockers: `--label blocked --assignee @me` |
| `pr-create.sh --title --body-file [--base] [--draft]` | Push branch (never main, never force), open PR |
| `ci-wait.sh [pr]` | Block until checks finish; exit 0 = green |
| `pr-merge.sh <pr> [--issue N]` | Squash-merge, delete branch, close issue |
| `board-move.sh --owner --project --issue --status` | Move card on Projects v2 board |

## glab scripts (GitLab twins)

`scripts/glab/` mirrors `scripts/gh/` for GitLab repos: `next-ticket.sh`,
`issue-create.sh`, `mr-create.sh`, `ci-wait.sh` (REST poll, `--timeout`),
`mr-merge.sh`, `ensure-labels.sh`, and `board-move.sh` (label-driven boards:
`--issue <iid> --scope workflow --value "In Progress"` swaps scoped labels).
Agents pick the set by `git remote get-url origin`.

> Status: shellcheck/CI-verified only — not yet exercised against a real
> GitLab instance (`glab` not installed on the authoring machine). Expect to
> patch flags on first real use.

## Other scripts

| Script | Does |
|---|---|
| `fastlane-quiet.sh <dir> <lane...>` | Run a fastlane lane, full log to file, print tail only. Failure → last 60 lines + log path. Keeps build noise out of agent context |
| `repo-init.sh --name X [--board] [--check ci]... [--dry-run]` | Bootstrap the ticket-loop pattern: repo + labels + linked Projects v2 board + branch protection (no force push/deletion, required checks). GitHub only |
| `maestro-quiet.sh <flow.yaml> [args...]` | Run a Maestro flow, full log to file, print tail only. Deterministic UI checks belong here, not in argent driving |

## Templates

`templates/` — canonical shapes for briefs, PR bodies, blocker issues, and
ADRs. gh-publisher starts from these instead of inventing structure; the
controller uses `brief.md` when writing implementer briefs.

Rule: don't wrap fastlane lanes in per-lane scripts — lanes ARE the script layer.
Logic goes in the Fastfile; scripts exist only to tame output or orchestrate
around fastlane (monorepo app→lane resolution). Document available lanes in each
project's `CLAUDE.md`.

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

Organization: flat folders, `<domain>-<topic>` names (`rn-haptics`,
`swift-testing-conventions`, `infra-gke-deploys`). No nesting by technology —
the install target is flat and routing ignores folders. Granularity: one skill
per decision area; if a body grows past ~100 lines, split it.

## Adding a crewmate

1. `mkdir crewmates/<name>`, write `PROMPT.md` (role, input, workflow, output
   contract, hard rules) and `meta.json`.
2. Keep the prompt model-agnostic: explicit contracts, no reliance on the model
   inferring unstated conventions — it must work on a cheap model.
3. `bun run generate`.

Keep the roster small: a crewmate earns its place only if the role repeats with
a fixed contract, needs tool restrictions, or runs on a different model tier.
Everything else is a general-purpose agent with a good brief.
