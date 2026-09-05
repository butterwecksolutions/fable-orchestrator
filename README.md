# Fable Orchestrator — Sovereign Dual-GPU Edition

**Fork of [codejunkie99/fable-orchestrator](https://github.com/codejunkie99/fable-orchestrator)** for local AI workstations.

| Role | Default | Hardware / cost |
|------|---------|-----------------|
| **Brain (orchestrator)** | Claude Fable 5.1, GPT‑5.6 Luna, or Grok | Cloud — few tokens (plan + adjudicate only) |
| **Worker Heavy** | LiteLLM `coder` | **CMP 170HX 64 GB** — large context, main implementation |
| **Worker Flash** | LiteLLM `sidekick` / `fast` | **RTX 3090** — loops, tests, mechanical work |

The brain **never** writes production code. Workers do the token volume via local OpenAI-compatible APIs (`http://127.0.0.1:4000/v1`).

```text
Cloud Brain ──packet──► task graph
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
     local-heavy (170HX)          local-flash (3090)
         coder                        sidekick/fast
```

## Repository layout

```text
skill/fable/
├── SKILL.md
├── agents/openai.yaml
└── scripts/
    ├── ask_fable.sh      # multi-brain helper (Claude / OpenAI / xAI)
    ├── fable-tui.sh      # interactive brain + worker selection
    └── worker-menu.sh    # prints callable local worker menu
config/
└── defaults.env          # env template (no secrets committed)
install.sh
tests/test_skill.sh
```

## Install

```bash
./install.sh --dry-run
./install.sh --copy
# optional: also install CLI helpers to /usr/local/bin (needs sudo)
./install.sh --copy --system-bins
```

Codex skill path default: `~/.codex/skills/fable`.  
Workstation path (AI OS): `/opt/ai/fable-orchestrator`.

## Configure

```bash
cp config/defaults.env ~/.config/fable-orchestrator/env
# edit keys for the cloud brain only — workers use local sk-local-sovereign
source ~/.config/fable-orchestrator/env
```

Or use the TUI (no keys in the repo):

```bash
./skill/fable/scripts/fable-tui.sh
# or after install:
fable-tui
```

## Use

```bash
# Classic skill invocation (Codex / agent runtime)
$fable build the feature

# Direct brain call with packet
printf '%s' "$PACKET" | ask_fable.sh

# TUI: pick brain + workers, then paste objective
fable-tui
```

Workers are always selected from the **callable menu** (LiteLLM aliases bound to dual GPUs). If a GPU backend is down, the menu reports it — no silent substitution.

## Dual-GPU mapping (Butterweck / Sovereign Agent OS)

| LiteLLM alias | Role | Typical backend |
|---------------|------|-----------------|
| `coder` | local-heavy | vLLM / llama-server on **CMP 170HX** (large ctx) |
| `sidekick` / `fast` | local-flash | llama-server on **RTX 3090** |
| `reasoner` | optional critique | qwq / local reasoner port |

Override with env:

```bash
export FABLE_WORKER_HEAVY=coder
export FABLE_WORKER_FLASH=sidekick
export FABLE_LITELLM_BASE=http://127.0.0.1:4000/v1
```

## Test

```bash
tests/test_skill.sh
```

## License

MIT (upstream). This fork keeps the same license.