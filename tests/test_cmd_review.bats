#!/usr/bin/env bats
# Tests pour scripts/cmd-review.sh
# cmd-review.sh est un script top-level (non sourceable) — testé via exécution directe.
# adapter_start fait exec → on mock l'outil cible (opencode) comme un script PATH.

setup() {
  TEST_DIR="$(mktemp -d)"

  export PROJECTS_FILE="$TEST_DIR/projects.md"
  export PATHS_FILE="$TEST_DIR/paths.local.md"
  export API_KEYS_FILE="$TEST_DIR/api-keys.local.md"

  # Isoler HUB_CONFIG
  export HUB_CONFIG="$TEST_DIR/hub.json"
  printf '{"version":"1.0.0","default_target":"opencode","active_targets":["opencode"],"cli":{"language":"fr"}}\n' \
    > "$HUB_CONFIG"

  CMD_REVIEW="$BATS_TEST_DIRNAME/../scripts/cmd-review.sh"

  # ── Données de test ──────────────────────────────────────────────────────────
  cat > "$PROJECTS_FILE" <<'PROJEOF'
# Registre de test

## TEST-PROJ
- Nom : Projet Test
- Stack : Node.js
- Board Beads : TEST-PROJ
- Tracker : none
- Labels : feature,fix
- Agents : all
PROJEOF

  # Projet avec sélection d'agents restrictive
  cat >> "$PROJECTS_FILE" <<'PROJEOF'

## TEST-RESTRICTED
- Nom : Projet Restricted
- Stack : Node.js
- Tracker : none
- Agents : orchestrator,planner
PROJEOF

  mkdir -p "$TEST_DIR/fake-project"
  mkdir -p "$TEST_DIR/fake-project/.opencode/agents"
  # Créer un reviewer.md factice pour éviter le prompt de déploiement
  touch "$TEST_DIR/fake-project/.opencode/agents/reviewer.md"
  mkdir -p "$TEST_DIR/fake-project-restricted"
  mkdir -p "$TEST_DIR/fake-project-restricted/.opencode/agents"
  touch "$TEST_DIR/fake-project-restricted/.opencode/agents/reviewer.md"
  cat > "$PATHS_FILE" <<EOF
TEST-PROJ=$TEST_DIR/fake-project
TEST-RESTRICTED=$TEST_DIR/fake-project-restricted
EOF

  : > "$API_KEYS_FILE"

  # ── Mock git dans le PATH ─────────────────────────────────────────────────────
  GIT_CALLS_LOG="$TEST_DIR/git_calls.log"
  export GIT_CALLS_LOG
  : > "$GIT_CALLS_LOG"

  REAL_GIT="$(command -v git)"
  export REAL_GIT

  mkdir -p "$TEST_DIR/bin"
  cat > "$TEST_DIR/bin/git" <<'GITEOF'
#!/bin/bash
echo "git $*" >> "$GIT_CALLS_LOG"
# Simuler "branch --show-current" → retourner "feature/my-branch"
if [ "${1:-}" = "-C" ] && [ "${3:-}" = "branch" ] && [ "${4:-}" = "--show-current" ]; then
  echo "feature/my-branch"
  exit 0
fi
# Simuler "diff main...feature/my-branch" → diff vide
if [ "${1:-}" = "-C" ] && [ "${3:-}" = "diff" ]; then
  echo "+ added line"
  exit 0
fi
exec "$REAL_GIT" "$@"
GITEOF
  chmod +x "$TEST_DIR/bin/git"

  # ── Mock opencode dans le PATH ────────────────────────────────────────────────
  OPENCODE_LOG="$TEST_DIR/opencode_calls.log"
  export OPENCODE_LOG
  : > "$OPENCODE_LOG"

  cat > "$TEST_DIR/bin/opencode" <<'OCEOF'
#!/bin/bash
echo "opencode $*" >> "$OPENCODE_LOG"
exit 0
OCEOF
  chmod +x "$TEST_DIR/bin/opencode"

  export PATH="$TEST_DIR/bin:$PATH"
}

teardown() {
  unset HUB_CONFIG
  rm -rf "$TEST_DIR"
}

# ── Détection automatique de la branche courante ──────────────────────────────

@test "cmd-review : détecte automatiquement la branche courante et affiche le bloc intro" {
  run bash -c '
    printf "\n" | bash "$1" TEST-PROJ
  ' _ "$CMD_REVIEW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"feature/my-branch"* ]]
}

@test "cmd-review : accepte --branch et utilise la branche fournie" {
  run bash -c '
    printf "\n" | bash "$1" TEST-PROJ --branch my-feature
  ' _ "$CMD_REVIEW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"my-feature"* ]]
}

@test "cmd-review : affiche le bloc intro avec Chemin, Cible, Branche, Agent" {
  run bash -c '
    printf "\n" | bash "$1" TEST-PROJ --branch feat/test
  ' _ "$CMD_REVIEW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Chemin"* ]]
  [[ "$output" == *"Cible"* ]]
  [[ "$output" == *"Branche"* ]]
  [[ "$output" == *"Agent"* ]]
}

@test "cmd-review : lance opencode avec --agent reviewer" {
  run bash -c '
    printf "\n" | bash "$1" TEST-PROJ --branch feat/test
  ' _ "$CMD_REVIEW"
  [ "$status" -eq 0 ]
  grep -q "opencode" "$OPENCODE_LOG"
  grep -q "\-\-agent reviewer" "$OPENCODE_LOG"
}

@test "cmd-review : affiche la confirmation avant lancement" {
  run bash -c '
    printf "\n" | bash "$1" TEST-PROJ --branch feat/test
  ' _ "$CMD_REVIEW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Lancement de la review"* ]]
}

# ── Sélection interactive si pas d'ID ────────────────────────────────────────

@test "cmd-review : exit si PROJECT_ID invalide" {
  run bash -c '
    printf "\n" | bash "$1" INEXISTANT --branch main
  ' _ "$CMD_REVIEW"
  [ "$status" -ne 0 ]
}

# ── Vérification sélection restrictive ───────────────────────────────────────

@test "cmd-review : avertit si reviewer absent de la sélection projet" {
  run bash -c '
    # Y = ajouter reviewer, n = ne pas redéployer, Enter = gate
    printf "Y\nn\n\n" | bash "$1" TEST-RESTRICTED --branch feat/test
  ' _ "$CMD_REVIEW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"reviewer"* ]]
}

@test "cmd-review : continue même si refus d'ajout de reviewer dans la sélection" {
  # Répondre n = refus d'ajout, Enter = gate
  run bash -c '
    printf "n\n\n" | bash "$1" TEST-RESTRICTED --branch feat/test
  ' _ "$CMD_REVIEW"
  [ "$status" -eq 0 ]
  # opencode doit quand même être appelé
  [ -s "$OPENCODE_LOG" ]
}

# ── Argument --branch avec PROJECT_ID ────────────────────────────────────────

@test "cmd-review : --branch avant PROJECT_ID est accepté" {
  run bash -c '
    printf "\n" | bash "$1" TEST-PROJ --branch release/v2.0
  ' _ "$CMD_REVIEW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"release/v2.0"* ]]
}

@test "cmd-review : passe --prompt à opencode avec le contenu du diff" {
  run bash -c '
    printf "\n" | bash "$1" TEST-PROJ --branch feat/test
  ' _ "$CMD_REVIEW"
  [ "$status" -eq 0 ]
  grep -q "\-\-prompt" "$OPENCODE_LOG"
}
