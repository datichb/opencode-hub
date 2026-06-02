#!/usr/bin/env bats
# Tests d'intégration multi-projets
# Vérifie : création multiple, switch, isolation, lifecycle complet

load helpers

setup() {
  common_setup

  export PROJECTS_FILE="$TEST_DIR/projects.md"
  export PATHS_FILE="$TEST_DIR/paths.local.md"
  export API_KEYS_FILE="$TEST_DIR/api-keys.local.md"
  export HUB_CONFIG="$TEST_DIR/hub.json"

    > "$HUB_CONFIG"

  SCRIPT_DIR="$BATS_TEST_DIRNAME/../scripts"

  # Créer les répertoires des projets
  mkdir -p "$TEST_DIR/proj-alpha"
  mkdir -p "$TEST_DIR/proj-beta"
  mkdir -p "$TEST_DIR/proj-gamma"

  # Registre avec 3 projets
  cat > "$PROJECTS_FILE" <<'EOF'
# Registre de test

## ALPHA
- Nom : Alpha Project
- Stack : Node.js
- Board Beads : ALPHA
- Tracker : jira
- Labels : feature,fix
- Agents : developer-frontend,developer-backend

## BETA
- Nom : Beta Project
- Stack : Python
- Board Beads : BETA
- Tracker : github
- Labels : feature
- Agents : developer-backend

## GAMMA
- Nom : Gamma Project
- Stack : Go
- Board Beads : GAMMA
- Tracker : none
- Labels : fix
- Agents : all
EOF

  cat > "$PATHS_FILE" <<EOF
ALPHA=$TEST_DIR/proj-alpha
BETA=$TEST_DIR/proj-beta
GAMMA=$TEST_DIR/proj-gamma
EOF

  : > "$API_KEYS_FILE"

  source "$SCRIPT_DIR/common.sh"
}

teardown() {
  common_teardown
}

# ── Création et lecture multi-projets ─────────────────────────────────────────

@test "multi-projets : les 3 projets sont accessibles via get_project_path" {
  local path_alpha path_beta path_gamma
  path_alpha=$(get_project_path "ALPHA")
  path_beta=$(get_project_path "BETA")
  path_gamma=$(get_project_path "GAMMA")
  [ "$path_alpha" = "$TEST_DIR/proj-alpha" ]
  [ "$path_beta"  = "$TEST_DIR/proj-beta" ]
  [ "$path_gamma" = "$TEST_DIR/proj-gamma" ]
}

@test "multi-projets : les projets ont des stacks différentes (lecture registre)" {
  # Lire la stack de chaque projet depuis PROJECTS_FILE via awk (section par section)
  local stack_alpha stack_beta stack_gamma
  stack_alpha=$(awk '/^## ALPHA/{f=1} f && /^- Stack/{print; exit}' "$PROJECTS_FILE" | sed 's/.*: //')
  stack_beta=$(awk  '/^## BETA/{f=1}  f && /^- Stack/{print; exit}' "$PROJECTS_FILE" | sed 's/.*: //')
  stack_gamma=$(awk '/^## GAMMA/{f=1} f && /^- Stack/{print; exit}' "$PROJECTS_FILE" | sed 's/.*: //')
  [ "$stack_alpha" = "Node.js" ]
  [ "$stack_beta"  = "Python"  ]
  [ "$stack_gamma" = "Go"      ]
}

@test "multi-projets : les projets ont des trackers différents" {
  local tracker_alpha tracker_beta tracker_gamma
  tracker_alpha=$(get_project_tracker "ALPHA")
  tracker_beta=$(get_project_tracker "BETA")
  tracker_gamma=$(get_project_tracker "GAMMA")
  [ "$tracker_alpha" = "jira"   ]
  [ "$tracker_beta"  = "github" ]
  [ "$tracker_gamma" = "none"   ]
}

@test "multi-projets : agents ALPHA isolés de BETA" {
  local agents_alpha agents_beta
  agents_alpha=$(get_project_agents "ALPHA")
  agents_beta=$(get_project_agents "BETA")
  # ALPHA a developer-frontend, BETA ne l'a pas
  [[ "$agents_alpha" =~ "developer-frontend" ]]
  [[ ! "$agents_beta" =~ "developer-frontend" ]]
}

@test "multi-projets : GAMMA a agents=all" {
  local agents_gamma
  agents_gamma=$(get_project_agents "GAMMA")
  [ "$agents_gamma" = "all" ]
}

# ── Isolation des configs déployées ──────────────────────────────────────────

@test "multi-projets : déploiement ALPHA n'affecte pas BETA" {
  # Déployer vers ALPHA
  run bash "$SCRIPT_DIR/cmd-deploy.sh" "ALPHA"
  # Vérifier que les fichiers de BETA restent vierges
  [ ! -d "$TEST_DIR/proj-beta/.opencode/agents" ] || \
    [ "$(ls -A "$TEST_DIR/proj-beta/.opencode/agents" 2>/dev/null)" = "" ]
}

@test "multi-projets : cmd-status affiche les 3 projets" {
  run bash "$SCRIPT_DIR/cmd-status.sh"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ALPHA" ]]
  [[ "$output" =~ "BETA"  ]]
  [[ "$output" =~ "GAMMA" ]]
}

@test "multi-projets : cmd-status --short affiche les 3 projets" {
  run bash "$SCRIPT_DIR/cmd-status.sh" --short
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ALPHA" ]]
  [[ "$output" =~ "BETA"  ]]
  [[ "$output" =~ "GAMMA" ]]
}

# ── Modification d'un projet sans impact sur les autres ───────────────────────

@test "multi-projets : modifier les agents ALPHA ne change pas BETA" {
  local before_beta
  before_beta=$(get_project_agents "BETA")
  # Modifier la ligne Agents d'ALPHA directement dans le fichier
  sed -i.bak 's/^- Agents : developer-frontend,developer-backend/- Agents : developer-fullstack/' "$PROJECTS_FILE"
  local after_beta
  after_beta=$(get_project_agents "BETA")
  [ "$before_beta" = "$after_beta" ]
}

@test "multi-projets : normalisation ID — alpha → ALPHA" {
  local path
  path=$(get_project_path "$(normalize_project_id "alpha")")
  [ "$path" = "$TEST_DIR/proj-alpha" ]
}

@test "multi-projets : projet inexistant retourne chemin vide" {
  local path
  path=$(get_project_path "INEXISTANT" 2>/dev/null || true)
  [ -z "$path" ]
}
