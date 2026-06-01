#!/usr/bin/env bats
# Tests edge cases — limites (labels, agents, longueur)
# Vérifie : 50+ labels, 50+ agents dans la config, noms très longs

load helpers

setup() {
  common_setup

  export PROJECTS_FILE="$TEST_DIR/projects.md"
  export PATHS_FILE="$TEST_DIR/paths.local.md"
  export API_KEYS_FILE="$TEST_DIR/api-keys.local.md"
  export HUB_CONFIG="$TEST_DIR/hub.json"
  printf '{"version":"1.0.0","default_target":"opencode","active_targets":["opencode"],"cli":{"language":"fr"}}\n' \
    > "$HUB_CONFIG"

  SCRIPT_DIR="$BATS_TEST_DIRNAME/../scripts"

  mkdir -p "$TEST_DIR/proj-limits"

  # Générer 50 labels
  local labels=""
  for i in $(seq 1 50); do
    labels="${labels}label-$i,"
  done
  labels="${labels%,}"

  # Générer 50 agents
  local agents=""
  for i in $(seq 1 50); do
    agents="${agents}agent-$i,"
  done
  agents="${agents%,}"

  # Nom très long (100 caractères)
  local long_name
  long_name=$(printf 'A%.0s' {1..100})

  cat > "$PROJECTS_FILE" <<EOF
# Registre de test

## MANY-LABELS
- Nom : Many Labels Project
- Stack : Node.js
- Board Beads : MANY-LABELS
- Tracker : none
- Labels : ${labels}
- Agents : all

## MANY-AGENTS
- Nom : Many Agents Project
- Stack : Python
- Board Beads : MANY-AGENTS
- Tracker : none
- Labels : test
- Agents : ${agents}

## LONG-NAME-PROJ
- Nom : ${long_name}
- Stack : Go
- Board Beads : LONG-NAME-PROJ
- Tracker : none
- Labels : test
- Agents : all
EOF

  cat > "$PATHS_FILE" <<EOF
MANY-LABELS=$TEST_DIR/proj-limits
MANY-AGENTS=$TEST_DIR/proj-limits
LONG-NAME-PROJ=$TEST_DIR/proj-limits
EOF

  : > "$API_KEYS_FILE"

  source "$SCRIPT_DIR/common.sh"
}

teardown() {
  common_teardown
}

# ── Beaucoup de labels ────────────────────────────────────────────────────────

@test "limits : 50 labels → get_project_labels ne crashe pas" {
  run bash -c '
    source "$1/common.sh"
    get_project_labels "MANY-LABELS" 2>/dev/null || echo ""
    echo "survived"
  ' _ "$SCRIPT_DIR"
  [[ "$output" =~ "survived" ]]
}

@test "limits : 50 labels → tous récupérés" {
  local labels
  labels=$(get_project_labels "MANY-LABELS" 2>/dev/null || echo "")
  # Doit contenir au moins label-1 et label-50
  [[ "$labels" =~ "label-1" ]]
  [[ "$labels" =~ "label-50" ]]
}

@test "limits : 50 labels → get_project_path fonctionne toujours" {
  local path
  path=$(get_project_path "MANY-LABELS")
  [ "$path" = "$TEST_DIR/proj-limits" ]
}

# ── Beaucoup d'agents ─────────────────────────────────────────────────────────

@test "limits : 50 agents → get_project_agents ne crashe pas" {
  run bash -c '
    source "$1/common.sh"
    get_project_agents "MANY-AGENTS" 2>/dev/null || echo ""
    echo "survived"
  ' _ "$SCRIPT_DIR"
  [[ "$output" =~ "survived" ]]
}

@test "limits : 50 agents → valeur non vide retournée" {
  local agents
  agents=$(get_project_agents "MANY-AGENTS" 2>/dev/null || echo "")
  [ -n "$agents" ]
}

@test "limits : 50 agents → agent-1 et agent-50 présents" {
  local agents
  agents=$(get_project_agents "MANY-AGENTS" 2>/dev/null || echo "")
  [[ "$agents" =~ "agent-1" ]]
  [[ "$agents" =~ "agent-50" ]]
}

# ── Nom très long ─────────────────────────────────────────────────────────────

@test "limits : nom de 100 caractères → get_project_path fonctionne" {
  local path
  path=$(get_project_path "LONG-NAME-PROJ")
  [ "$path" = "$TEST_DIR/proj-limits" ]
}

@test "limits : nom de 100 caractères → get_project_tracker fonctionne" {
  local tracker
  tracker=$(get_project_tracker "LONG-NAME-PROJ")
  [ "$tracker" = "none" ]
}

# ── cmd-status avec projets aux limites ───────────────────────────────────────

@test "limits : cmd-status avec projets aux limites → s'exécute sans crash" {
  run bash "$SCRIPT_DIR/cmd-status.sh"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "MANY-LABELS" ]]
  [[ "$output" =~ "MANY-AGENTS" ]]
}
