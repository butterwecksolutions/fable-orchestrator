#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SRC="$ROOT/skill/fable"

fail=0
check() { if "$@"; then echo "OK: $*"; else echo "FAIL: $*"; fail=1; fi; }

check test -f "$SRC/SKILL.md"
check test -f "$SRC/scripts/ask_fable.sh"
check test -f "$SRC/scripts/fable-tui.sh"
check test -f "$SRC/scripts/worker-menu.sh"
check test -f "$SRC/agents/openai.yaml"
check test -f "$ROOT/config/defaults.env"

bash -n "$SRC/scripts/ask_fable.sh"
bash -n "$SRC/scripts/fable-tui.sh"
bash -n "$SRC/scripts/worker-menu.sh"
bash -n "$ROOT/install.sh"
echo "OK: bash -n scripts"

grep -q 'local-heavy' "$SRC/SKILL.md" || { echo 'FAIL: SKILL missing local-heavy'; fail=1; }
grep -q 'local-flash' "$SRC/SKILL.md" || { echo 'FAIL: SKILL missing local-flash'; fail=1; }
grep -q 'FABLE_BRAIN' "$SRC/scripts/ask_fable.sh" || { echo 'FAIL: ask_fable brain switch'; fail=1; }
grep -q 'CMP\|170HX\|170hx\|coder' "$SRC/scripts/worker-menu.sh" || { echo 'FAIL: worker-menu GPU map'; fail=1; }

# no obvious secrets in tree
if grep -RInE 'sk-[a-zA-Z0-9]{20,}|xai-[a-zA-Z0-9]{20,}' "$ROOT" --exclude-dir=.git 2>/dev/null | grep -v sk-local-sovereign; then
  echo 'FAIL: credential-shaped string found'
  fail=1
else
  echo 'OK: no live credential-shaped secrets'
fi

# dry-run install into temp
tmpdir="$(mktemp -d)"
"$ROOT/install.sh" --dry-run --target "$tmpdir/skills" >/dev/null
"$ROOT/install.sh" --copy --target "$tmpdir/skills"
check test -x "$tmpdir/skills/fable/scripts/ask_fable.sh"
rm -rf "$tmpdir"

if ((fail)); then
  echo "SOME CHECKS FAILED"
  exit 1
fi
echo "ALL CHECKS PASSED"
