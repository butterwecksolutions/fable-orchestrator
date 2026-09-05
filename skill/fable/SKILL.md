---
name: fable
description: >
  Cloud brain (Claude Fable 5.1, GPT-5.6 Luna, or Grok) orchestrates only.
  Implementation runs on two local workstation workers via LiteLLM:
  local-heavy (coder → CMP 170HX, large context) and local-flash (sidekick/fast → RTX 3090).
  Use when the user invokes $fable or asks for Fable-style orchestration.
---

# Fable orchestrator — Sovereign Dual-GPU

The **brain** plans and adjudicates only. It does **not** write production code
or own the workspace. The **runtime** (Codex, OpenCode, Hermes, or shell) spawns
workers, owns files, runs tools, verifies, and reports to the user.

## Roles

| Role | Who | Tokens |
|------|-----|--------|
| Brain | Fable 5.1 / GPT-5.6 Luna / Grok (user choice) | Few — plan + adjudicate |
| local-heavy | LiteLLM `coder` on **CMP 170HX 64 GB** | Most implementation, large context |
| local-flash | LiteLLM `sidekick` or `fast` on **RTX 3090** | Loops, tests, mechanical throughput |

## Invocation

Treat everything after `$fable` as the objective. Optionally set brain/workers
via env or `fable-tui`:

- `$fable build the feature`
- `$fable debug this; implementer: local-heavy`
- `FABLE_BRAIN=xai fable-tui`

Model names are requests, not guesses. Before dispatch, use the callable menu
from `scripts/worker-menu.sh`. Use only workers that report **up**. If a
requested worker is down, say so; substitute only when low-risk, otherwise ask.

### Classifier (when user did not pick a worker)

1. Loop / repeated iteration / high-throughput mechanical → **local-flash**
2. Normal implementation / multi-file feature work → **local-heavy**
3. Planning, review, adjudication → **brain only** (outside worker graph)

Never assign implementation to the cloud brain. Never invent a model that is
not on the callable menu.

## Workflow

1. Read the objective; inspect enough of the workspace for facts.
2. Build a compact orchestration packet: objective, acceptance criteria,
   workspace context, constraints, protected files, evidence, **callable worker
   menu**, concurrency limit (default 2 = one job per GPU), user preferences.
3. Send the packet to `scripts/ask_fable.sh` (brain selected by `FABLE_BRAIN`).
4. Require a bounded task graph: id, purpose, dependencies, worker id from the
   menu, ownership, expected output, verification, stop condition.
5. Validate graph for safety and scope. Runtime has final say.
6. Spawn ready nodes in parallel up to `FABLE_MAX_PARALLEL` (typically 2).
7. Collect results; run `/opt/ai/scripts/qc-lint.sh`, `qc-typecheck.sh`,
   `qc-test.sh` when available. Cap brain calls at three unless user continues.
8. Finish only when acceptance criteria pass. Report workers used and proof.

Display brain output under:

```text
Brain speaks:
```

## Boundaries

- Brain plans and adjudicates; it does not replace local workers for code volume.
- No secrets in packets. Cloud keys stay in env / CLI auth only.
- Destructive ops, publish, spend keep normal approval gates.
- If delegation adds no value, one local worker after the plan is enough.

## Calling the brain

```bash
printf '%s' "$PACKET" | "$HOME/.codex/skills/fable/scripts/ask_fable.sh"
# or workstation:
printf '%s' "$PACKET" | /opt/ai/fable-orchestrator/skill/fable/scripts/ask_fable.sh
```
