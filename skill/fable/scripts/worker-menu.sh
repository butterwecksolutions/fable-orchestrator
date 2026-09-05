#!/usr/bin/env bash
# Print callable local workers for the orchestration packet (dual-GPU workstation).
set -euo pipefail

BASE="${FABLE_LITELLM_BASE:-http://127.0.0.1:4000/v1}"
KEY="${FABLE_LITELLM_KEY:-sk-local-sovereign}"
HEAVY="${FABLE_WORKER_HEAVY:-coder}"
FLASH="${FABLE_WORKER_FLASH:-sidekick}"

probe() {
  local name="$1"
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer $KEY" \
    -H "Content-Type: application/json" \
    --max-time 3 \
    "$BASE/models" 2>/dev/null || echo 000)"
  if [[ "$code" == "200" ]]; then
    echo "up"
  else
    echo "down(http=$code)"
  fi
}

litellm_status="$(probe litellm)"

cat <<EOF
CALLABLE_WORKER_MENU
====================
litellm_base: $BASE
litellm_status: $litellm_status
max_parallel: ${FABLE_MAX_PARALLEL:-2}

workers:
  - id: local-heavy
    litellm_model: $HEAVY
    gpu: CMP_170HX_64GB
    role: main implementation, large context, multi-file features
    status: $litellm_status

  - id: local-flash
    litellm_model: $FLASH
    gpu: RTX_3090
    role: loops, tests, mechanical / high-throughput edits
    status: $litellm_status

routing_rules:
  - mechanical_or_loop -> local-flash
  - implementation -> local-heavy
  - plan_review_adjudicate -> brain_only (not a worker)

notes:
  - Prefer agent pins local-heavy / local-flash over raw model strings.
  - If litellm is down, do not invent workers; report blocker.
  - Optional aliases if present in LiteLLM: fast, reasoner, coder-reason.
EOF
