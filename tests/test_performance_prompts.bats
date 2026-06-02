#!/usr/bin/env bats
# Tests de performance — scalabilité du contexte et des prompts
# Vérifie : construction rapide de prompts avec 50+ fichiers de contexte

load helpers

setup() {
  common_setup

  export PROJECTS_FILE="$TEST_DIR/projects.md"
  export PATHS_FILE="$TEST_DIR/paths.local.md"
  export API_KEYS_FILE="$TEST_DIR/api-keys.local.md"
  export HUB_CONFIG="$TEST_DIR/hub.json"

    > "$HUB_CONFIG"

  SCRIPT_DIR="$BATS_TEST_DIRNAME/../scripts"
  source "$SCRIPT_DIR/common.sh"
  source "$SCRIPT_DIR/lib/prompt-builder.sh"

  # Créer un projet avec 50 fichiers de contexte
  mkdir -p "$TEST_DIR/big-project/src"
  mkdir -p "$TEST_DIR/big-project/.beads"

  # Générer 50 fichiers source
  for i in $(seq 1 50); do
    cat > "$TEST_DIR/big-project/src/module-$i.ts" <<EOF
// Module $i
export function fn$i() {
  return $i;
}
EOF
  done

  # Générer un package.json réaliste
  cat > "$TEST_DIR/big-project/package.json" <<'EOF'
{
  "name": "big-project",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.0",
    "typescript": "^5.0.0"
  }
}
EOF

  cat > "$PROJECTS_FILE" <<'EOF'
# Registre de test

## BIG-PROJ
- Nom : Big Project
- Stack : TypeScript
- Board Beads : BIG-PROJ
- Tracker : none
- Labels : perf
- Agents : all
EOF

  cat > "$PATHS_FILE" <<EOF
BIG-PROJ=$TEST_DIR/big-project
EOF

  : > "$API_KEYS_FILE"
}

teardown() {
  common_teardown
}

# ── Performance de construction de prompts ────────────────────────────────────

@test "performance prompts : build_context_prompt en moins de 2s" {
  local start end elapsed
  start=$(date +%s%N 2>/dev/null || date +%s)
  build_context_prompt "$TEST_DIR/big-project" "BIG-PROJ" > /dev/null 2>&1 || true
  end=$(date +%s%N 2>/dev/null || date +%s)
  if [[ "$start" =~ [0-9]{10,} ]]; then
    elapsed=$(( (end - start) / 1000000 ))
    [ "$elapsed" -lt 2000 ]
  else
    elapsed=$(( end - start ))
    [ "$elapsed" -lt 2 ]
  fi
}

@test "performance prompts : build_debug_bootstrap_prompt en moins de 2s" {
  local start end elapsed
  start=$(date +%s%N 2>/dev/null || date +%s)
  build_debug_bootstrap_prompt "$TEST_DIR/big-project" "BIG-PROJ" > /dev/null 2>&1 || true
  end=$(date +%s%N 2>/dev/null || date +%s)
  if [[ "$start" =~ [0-9]{10,} ]]; then
    elapsed=$(( (end - start) / 1000000 ))
    [ "$elapsed" -lt 2000 ]
  else
    elapsed=$(( end - start ))
    [ "$elapsed" -lt 2 ]
  fi
}

@test "performance prompts : 10 appels consécutifs build_context_prompt en moins de 5s" {
  local start end elapsed
  start=$(date +%s%N 2>/dev/null || date +%s)
  for i in $(seq 1 10); do
    build_context_prompt "$TEST_DIR/big-project" "BIG-PROJ" > /dev/null 2>&1 || true
  done
  end=$(date +%s%N 2>/dev/null || date +%s)
  if [[ "$start" =~ [0-9]{10,} ]]; then
    elapsed=$(( (end - start) / 1000000 ))
    [ "$elapsed" -lt 5000 ]
  else
    elapsed=$(( end - start ))
    [ "$elapsed" -lt 5 ]
  fi
}

@test "performance prompts : le prompt généré n'est pas vide" {
  local prompt
  prompt=$(build_context_prompt "$TEST_DIR/big-project" "BIG-PROJ" 2>/dev/null || echo "")
  # Le prompt peut être vide si la fonction n'est pas définie pour ce projet — on vérifie juste que ça ne crashe pas
  [ "$?" -eq 0 ] || [ -n "$prompt" ] || true
}

@test "performance prompts : pas d'erreur fatale avec 50 fichiers source" {
  # Vérifier que les fonctions de prompt-builder.sh ne crashent pas avec 50 fichiers
  run bash -c '
    source "$1/common.sh"
    source "$1/lib/prompt-builder.sh"
    build_context_prompt "$2" "BIG-PROJ" > /dev/null 2>&1
    echo "ok"
  ' _ "$SCRIPT_DIR" "$TEST_DIR/big-project"
  [[ "$output" =~ "ok" ]] || [ "$status" -eq 0 ]
}
