#!/usr/bin/env bash
# Multi-brain orchestration helper: Fable (Claude CLI) | OpenAI | xAI Grok.
# Workers are never invoked here — only the cloud/local brain for the task graph.
set -euo pipefail

load_env() {
  local f
  for f in \
    "${FABLE_ENV:-}" \
    "$HOME/.config/fable-orchestrator/env" \
    /opt/ai/fable-orchestrator/config/defaults.env \
    "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)/config/defaults.env"
  do
    [[ -n "$f" && -f "$f" ]] || continue
    # shellcheck disable=SC1090
    set -a
    # strip comments / blank
    # shellcheck disable=SC1091
    source <(grep -v '^\s*#' "$f" | grep -v '^\s*$' || true)
    set +a
    break
  done
}
load_env

if [[ $# -gt 0 ]]; then
  packet="$*"
else
  packet="$(cat)"
fi

if [[ -z "${packet//[[:space:]]/}" ]]; then
  echo "Provide a non-empty orchestration packet on stdin or as arguments." >&2
  exit 64
fi

BRAIN="${FABLE_BRAIN:-fable}"
HEAVY="${FABLE_WORKER_HEAVY:-coder}"
FLASH="${FABLE_WORKER_FLASH:-sidekick}"

system_prompt="You are the orchestration controller (brain) for a dual-GPU local coding workstation. You plan and adjudicate only; never assign yourself implementation and never write code. Use only the supplied packet. Return a concise executable task graph, not implementation.

For each node specify: id, purpose, dependencies, recommended worker id chosen ONLY from the supplied callable menu (local-heavy or local-flash), exclusive file or responsibility ownership, expected output, verification, and stop condition.

Worker mapping:
- local-heavy → LiteLLM model '${HEAVY}' on CMP 170HX 64GB (large context, main implementation)
- local-flash → LiteLLM model '${FLASH}' on RTX 3090 (loops, tests, mechanical throughput)

Classifier when the user did not choose a worker: mechanical/loop/high-throughput → local-flash; other implementation → local-heavy; planning/review → brain only (outside worker graph). Never assign implementation to the brain or to any model not on the menu. If neither worker is callable, report the blocker; never invent models.

Identify nodes safe to run in parallel (max ${FABLE_MAX_PARALLEL:-2}). Minimize agents. Preserve user scope and approval boundaries. End with an integration and final-verification node (prefer local-flash for test runs). Do not expose chain-of-thought; decisions and brief rationale only.

Start with one short line per ready assignment: Worker — Model: bounded responsibility."

openai_compatible_chat() {
  local base="$1" key="$2" model="$3"
  [[ -n "$key" ]] || { echo "Missing API key for brain provider." >&2; return 1; }
  local payload response
  payload="$(python3 -c '
import json,sys
base_prompt=sys.argv[1]
packet=sys.argv[2]
model=sys.argv[3]
print(json.dumps({
  "model": model,
  "temperature": 0.2,
  "messages": [
    {"role": "system", "content": base_prompt},
    {"role": "user", "content": packet},
  ],
}))
' "$system_prompt" "$packet" "$model")"
  response="$(curl -fsS --max-time 180 \
    -H "Authorization: Bearer $key" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "${base%/}/chat/completions")"
  python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["choices"][0]["message"]["content"])' <<<"$response"
}

run_claude_fable() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "Claude Code CLI not on PATH (needed for FABLE_BRAIN=fable)." >&2
    return 127
  fi
  local fable_effort="${FABLE_EFFORT:-low}"
  local model_args=()
  [[ -n "${FABLE_MODEL:-}" ]] && model_args=(--model "$FABLE_MODEL")
  claude \
    --print \
    "${model_args[@]}" \
    --effort "$fable_effort" \
    --permission-mode dontAsk \
    --tools "" \
    --no-session-persistence \
    --output-format text \
    --system-prompt "$system_prompt" \
    "$packet"
}

response=""
label=""

case "$BRAIN" in
  fable|claude)
    response="$(run_claude_fable)" || exit $?
    label="Fable/Claude (${FABLE_MODEL:-default})"
    ;;
  openai|luna)
    response="$(openai_compatible_chat \
      "${OPENAI_BRAIN_BASE:-https://api.openai.com/v1}" \
      "${OPENAI_API_KEY:-}" \
      "${OPENAI_BRAIN_MODEL:-gpt-5.6}")" || exit $?
    label="OpenAI (${OPENAI_BRAIN_MODEL:-gpt-5.6})"
    ;;
  xai|grok)
    response="$(openai_compatible_chat \
      "${XAI_BRAIN_BASE:-https://api.x.ai/v1}" \
      "${XAI_API_KEY:-}" \
      "${XAI_BRAIN_MODEL:-grok-4}")" || exit $?
    label="xAI (${XAI_BRAIN_MODEL:-grok-4})"
    ;;
  *)
    echo "Unknown FABLE_BRAIN=$BRAIN (use fable|openai|xai)." >&2
    exit 64
    ;;
esac

printf 'Brain speaks (%s):\n\n%s\n' "$label" "$response"
