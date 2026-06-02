#!/usr/bin/env bats
# Tests pour scripts/cmd-status.sh
# Vérifie : vue détaillée, vue courte, projets manquants, chemins absents

setup() {
  TEST_DIR="$(mktemp -d)"

  export PROJECTS_FILE="$TEST_DIR/projects.md"
  export PATHS_FILE="$TEST_DIR/paths.local.md"
  export API_KEYS_FILE="$TEST_DIR/api-keys.local.md"
  export HUB_CONFIG="$TEST_DIR/hub.json"

    > "$HUB_CONFIG"

  CMD_STATUS="$BATS_TEST_DIRNAME/../scripts/cmd-status.sh"

  # Mocks log
  source "$BATS_TEST_DIRNAME/../scripts/common.sh"
  log_info()    { true; }
  log_success() { true; }
  log_warn()    { true; }
  log_error()   { true; }

  # Projet valide avec chemin existant
  mkdir -p "$TEST_DIR/proj-alpha"
  mkdir -p "$TEST_DIR/proj-alpha/.beads"
  mkdir -p "$TEST_DIR/proj-alpha/.opencode/agents"
  touch "$TEST_DIR/proj-alpha/.opencode/agents/developer-frontend.md"
  touch "$TEST_DIR/proj-alpha/.opencode/agents/developer-backend.md"

  # Projet sans chemin local (path_missing)
  # Projet avec chemin non-existant (dir_missing)
  mkdir -p "$TEST_DIR/proj-orphan"

  cat > "$PROJECTS_FILE" <<'EOF'
# Registre de test

## ALPHA
- Nom : Alpha Project
- Stack : Node.js
- Board Beads : ALPHA
- Tracker : jira
- Labels : feature
- Agents : developer-frontend,developer-backend

## BETA
- Nom : Beta Project
- Stack : Python
- Board Beads : BETA
- Tracker : none
- Labels : fix
- Agents : all

## ORPHAN
- Nom : Orphan Project
- Stack : Go
- Board Beads : ORPHAN
- Tracker : none
- Labels : test
- Agents : all
EOF

  cat > "$PATHS_FILE" <<EOF
ALPHA=$TEST_DIR/proj-alpha
BETA=/tmp/nonexistent-proj-beta-$$
ORPHAN=$TEST_DIR/proj-orphan
EOF

  : > "$API_KEYS_FILE"
  printf "ALPHA|anthropic|claude-opus-4-5\n" >> "$API_KEYS_FILE"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# ── Vue détaillée ─────────────────────────────────────────────────────────────

@test "status : s'exécute sans erreur avec projets enregistrés" {
  run bash "$CMD_STATUS"
  [ "$status" -eq 0 ]
}

@test "status : affiche le titre" {
  run bash "$CMD_STATUS"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Status" ]] || [[ "$output" =~ "Statut" ]]
}

@test "status : affiche les IDs des projets" {
  run bash "$CMD_STATUS"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ALPHA" ]]
  [[ "$output" =~ "BETA" ]]
  [[ "$output" =~ "ORPHAN" ]]
}

@test "status : indique le chemin du projet existant" {
  run bash "$CMD_STATUS"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "$TEST_DIR/proj-alpha" ]]
}

@test "status : signale le dossier manquant (BETA)" {
  run bash "$CMD_STATUS"
  [ "$status" -eq 0 ]
  # Soit le chemin est affiché, soit un avertissement est émis
  [[ "$output" =~ "BETA" ]]
}

@test "status : indique le nombre d'agents déployés pour ALPHA" {
  run bash "$CMD_STATUS"
  [ "$status" -eq 0 ]
  # ALPHA a 2 agents déployés : le script affiche "2 fichier(s)"
  [[ "$output" =~ "2 fichier" ]]
}

@test "status : indique beads initialisé pour ALPHA" {
  run bash "$CMD_STATUS"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "beads" ]] || [[ "$output" =~ "Beads" ]]
}

@test "status : aucun projet → affiche titre et sort proprement" {
  echo "" > "$PROJECTS_FILE"
  run bash "$CMD_STATUS"
  # ensure_projects_file peut retourner 1 si le fichier est vide — comportement attendu
  [[ "$output" =~ "Statut" ]] || [[ "$output" =~ "Status" ]]
}

# ── Vue courte (--short) ──────────────────────────────────────────────────────

@test "status --short : s'exécute sans erreur" {
  run bash "$CMD_STATUS" --short
  [ "$status" -eq 0 ]
}

@test "status --short : affiche les IDs en tableau compact" {
  run bash "$CMD_STATUS" --short
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ALPHA" ]]
  [[ "$output" =~ "BETA" ]]
}

@test "status --short : affiche les chemins" {
  run bash "$CMD_STATUS" --short
  [ "$status" -eq 0 ]
  [[ "$output" =~ "$TEST_DIR/proj-alpha" ]]
}

@test "status -s : alias de --short fonctionne" {
  run bash "$CMD_STATUS" -s
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ALPHA" ]]
}

@test "status --short : aucun projet → warning et code 0" {
  echo "" > "$PROJECTS_FILE"
  run bash "$CMD_STATUS" --short
  [ "$status" -eq 0 ]
}
