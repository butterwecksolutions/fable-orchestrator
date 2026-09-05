#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: install.sh --dry-run|--copy [--target DIR] [--system-bins] [--workstation]

  --target DIR     Skills root (default: ~/.codex/skills)
  --system-bins    Install fable-tui / ask_fable / worker-menu into /usr/local/bin
  --workstation    Also copy tree to /opt/ai/fable-orchestrator
USAGE
}

mode=''
target_root="${FABLE_SKILLS_DIR:-}"
system_bins=0
workstation=0

while (($#)); do
  case "$1" in
    --dry-run) [[ -z "$mode" ]] || { echo 'Choose only one mode.' >&2; exit 64; }; mode='dry-run' ;;
    --copy)    [[ -z "$mode" ]] || { echo 'Choose only one mode.' >&2; exit 64; }; mode='copy' ;;
    --target)
      (($# >= 2)) || { echo '--target requires a directory.' >&2; exit 64; }
      target_root="$2"; shift
      ;;
    --system-bins) system_bins=1 ;;
    --workstation) workstation=1 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 64 ;;
  esac
  shift
done

[[ -n "$mode" ]] || { usage >&2; exit 64; }
if [[ -z "$target_root" ]]; then
  [[ -n "${HOME:-}" ]] || { echo 'Set HOME or pass --target DIR.' >&2; exit 64; }
  target_root="$HOME/.codex/skills"
fi
[[ "$target_root" != '/' ]] || { echo 'Refusing /' >&2; exit 64; }

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source_root="$repo_root/skill/fable"
destination="$target_root/fable"

required=(
  SKILL.md
  scripts/ask_fable.sh
  scripts/fable-tui.sh
  scripts/worker-menu.sh
  agents/openai.yaml
)
for relative_path in "${required[@]}"; do
  [[ -f "$source_root/$relative_path" ]] || {
    echo "Missing: $source_root/$relative_path" >&2
    exit 66
  }
done

if [[ "$mode" == 'dry-run' ]]; then
  printf 'Would install skill → %s\n' "$destination"
  for relative_path in "${required[@]}"; do
    printf 'Would copy: %s\n' "$destination/$relative_path"
  done
  ((system_bins)) && echo 'Would link binaries into /usr/local/bin'
  ((workstation)) && echo 'Would copy tree → /opt/ai/fable-orchestrator'
  exit 0
fi

mkdir -p "$destination/scripts" "$destination/agents"
cp "$source_root/SKILL.md" "$destination/SKILL.md"
cp "$source_root/agents/openai.yaml" "$destination/agents/openai.yaml"
cp "$source_root/scripts/ask_fable.sh" "$destination/scripts/ask_fable.sh"
cp "$source_root/scripts/fable-tui.sh" "$destination/scripts/fable-tui.sh"
cp "$source_root/scripts/worker-menu.sh" "$destination/scripts/worker-menu.sh"
chmod 0755 "$destination/scripts/"*.sh

if ((system_bins)); then
  for b in ask_fable fable-tui worker-menu; do
    ln -sfn "$destination/scripts/${b}.sh" "/usr/local/bin/$b"
  done
  # alias without .sh
  ln -sfn "$destination/scripts/ask_fable.sh" /usr/local/bin/ask_fable
  ln -sfn "$destination/scripts/fable-tui.sh" /usr/local/bin/fable-tui
  ln -sfn "$destination/scripts/worker-menu.sh" /usr/local/bin/worker-menu
fi

if ((workstation)); then
  mkdir -p /opt/ai/fable-orchestrator
  cp -a "$repo_root/." /opt/ai/fable-orchestrator/
  chmod 0755 /opt/ai/fable-orchestrator/skill/fable/scripts/*.sh
fi

mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/fable-orchestrator"
if [[ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/fable-orchestrator/env" ]]; then
  cp "$repo_root/config/defaults.env" "${XDG_CONFIG_HOME:-$HOME/.config}/fable-orchestrator/env"
  chmod 600 "${XDG_CONFIG_HOME:-$HOME/.config}/fable-orchestrator/env"
fi

printf 'Installed Fable skill at %s\n' "$destination"
echo "Edit brain keys in: ${XDG_CONFIG_HOME:-$HOME/.config}/fable-orchestrator/env"
echo "Try: fable-tui   or   $destination/scripts/fable-tui.sh"
