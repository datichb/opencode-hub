#!/bin/bash
# ocp — switcher interactif de providers opencode
# Usage : ocp [--list|-l] | ocp <provider> [oc start args...]
set -euo pipefail

HUB_DIR="$(cd "$(dirname "$0")" && pwd)"
PROVIDERS_DIR="$HUB_DIR/config/providers"
OC="$HUB_DIR/oc.sh"

# ocp --list / ocp -l
if [ "${1:-}" = "--list" ] || [ "${1:-}" = "-l" ]; then
  echo "Providers disponibles :"
  for f in "$PROVIDERS_DIR"/*.json; do
    [ -f "$f" ] && echo "  $(basename "$f" .json)"
  done
  exit 0
fi

# ocp sans argument — picker interactif
if [ $# -eq 0 ]; then
  providers=()
  for f in "$PROVIDERS_DIR"/*.json; do
    [ -f "$f" ] && providers+=("$(basename "$f" .json)")
  done
  if [ ${#providers[@]} -eq 0 ]; then
    echo "❌ Aucun provider trouvé dans $PROVIDERS_DIR" >&2
    echo "   Lancer : oc provider init" >&2
    exit 1
  fi
  if command -v fzf &>/dev/null; then
    provider=$(printf '%s\n' "${providers[@]}" | fzf --prompt="Provider > ") || true
  else
    echo "Choisir un provider :"
    select provider in "${providers[@]}"; do
      [ -n "$provider" ] && break
    done
  fi
  [ -z "${provider:-}" ] && exit 1
  bash "$OC" start --provider "$provider"
  exit $?
fi

# ocp <provider> [args...]
provider="$1"
shift

if [ ! -f "$PROVIDERS_DIR/${provider}.json" ]; then
  echo "❌ Provider '${provider}' introuvable dans $PROVIDERS_DIR" >&2
  echo "   Providers disponibles : ocp --list" >&2
  exit 1
fi

bash "$OC" start --provider "$provider" "$@"
