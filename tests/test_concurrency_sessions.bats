#!/usr/bin/env bats
# Tests de concurrence — sessions simultanées sans corruption
# Vérifie : écriture/lecture concurrente du registre, isolation des sessions

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
  source "$SCRIPT_DIR/common.sh"

  # Registre de base
  cat > "$PROJECTS_FILE" <<'EOF'
# Registre de test

## CONCURRENT-A
- Nom : Concurrent A
- Stack : Node.js
- Board Beads : CONCURRENT-A
- Tracker : none
- Labels : concurrent
- Agents : all

## CONCURRENT-B
- Nom : Concurrent B
- Stack : Python
- Board Beads : CONCURRENT-B
- Tracker : none
- Labels : concurrent
- Agents : all
EOF

  cat > "$PATHS_FILE" <<EOF
CONCURRENT-A=$TEST_DIR/proj-a
CONCURRENT-B=$TEST_DIR/proj-b
EOF

  mkdir -p "$TEST_DIR/proj-a" "$TEST_DIR/proj-b"
  : > "$API_KEYS_FILE"
}

teardown() {
  common_teardown
}

# ── Lecture concurrente ───────────────────────────────────────────────────────

@test "concurrence : 5 lectures simultanées de get_project_path sans corruption" {
  local pids=() results=()
  local result_dir="$TEST_DIR/results"
  mkdir -p "$result_dir"

  # Lancer 5 lectures en parallèle
  for i in $(seq 1 5); do
    bash -c '
      source "$1/common.sh"
      get_project_path "CONCURRENT-A" > "$2/result-$3"
    ' _ "$SCRIPT_DIR" "$result_dir" "$i" &
    pids+=($!)
  done

  # Attendre tous les processus
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  # Vérifier que toutes les lectures ont retourné le bon chemin
  local failures=0
  for i in $(seq 1 5); do
    local val
    val=$(cat "$result_dir/result-$i" 2>/dev/null)
    [ "$val" = "$TEST_DIR/proj-a" ] || failures=$((failures + 1))
  done
  [ "$failures" -eq 0 ]
}

@test "concurrence : 5 appels simultanés get_project_tracker sans erreur" {
  local pids=()
  local result_dir="$TEST_DIR/results-tracker"
  mkdir -p "$result_dir"

  for i in $(seq 1 5); do
    bash -c '
      source "$1/common.sh"
      get_project_tracker "CONCURRENT-B" > "$2/tracker-$3"
    ' _ "$SCRIPT_DIR" "$result_dir" "$i" &
    pids+=($!)
  done

  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  local failures=0
  for i in $(seq 1 5); do
    local val
    val=$(cat "$result_dir/tracker-$i" 2>/dev/null)
    [ "$val" = "none" ] || failures=$((failures + 1))
  done
  [ "$failures" -eq 0 ]
}

@test "concurrence : 10 lectures mixtes (A et B) sans interférence" {
  local pids=()
  local result_dir="$TEST_DIR/results-mixed"
  mkdir -p "$result_dir"

  for i in $(seq 1 5); do
    bash -c '
      source "$1/common.sh"
      get_project_path "CONCURRENT-A" > "$2/a-$3"
      get_project_path "CONCURRENT-B" >> "$2/b-$3"
    ' _ "$SCRIPT_DIR" "$result_dir" "$i" &
    pids+=($!)
  done

  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  # Toutes les lectures de A doivent donner proj-a
  local failures=0
  for i in $(seq 1 5); do
    local val
    val=$(cat "$result_dir/a-$i" 2>/dev/null)
    [ "$val" = "$TEST_DIR/proj-a" ] || failures=$((failures + 1))
    val=$(cat "$result_dir/b-$i" 2>/dev/null)
    [ "$val" = "$TEST_DIR/proj-b" ] || failures=$((failures + 1))
  done
  [ "$failures" -eq 0 ]
}

# ── Isolation des fichiers temporaires ───────────────────────────────────────

@test "concurrence : PROJECTS_FILE n'est pas modifié par des lectures concurrentes" {
  local before after
  before=$(md5 -q "$PROJECTS_FILE" 2>/dev/null || md5sum "$PROJECTS_FILE" 2>/dev/null | awk '{print $1}')

  local pids=()
  for i in $(seq 1 10); do
    bash -c '
      source "$1/common.sh"
      get_project_path "CONCURRENT-A" > /dev/null
      get_project_agents "CONCURRENT-B" > /dev/null
    ' _ "$SCRIPT_DIR" &
    pids+=($!)
  done

  for pid in "${pids[@]}"; do wait "$pid"; done

  after=$(md5 -q "$PROJECTS_FILE" 2>/dev/null || md5sum "$PROJECTS_FILE" 2>/dev/null | awk '{print $1}')
  [ "$before" = "$after" ]
}

@test "concurrence : PATHS_FILE n'est pas corrompu après 10 lectures simultanées" {
  local before after
  before=$(wc -l < "$PATHS_FILE")

  local pids=()
  for i in $(seq 1 10); do
    bash -c '
      source "$1/common.sh"
      get_project_path "CONCURRENT-A" > /dev/null
    ' _ "$SCRIPT_DIR" &
    pids+=($!)
  done

  for pid in "${pids[@]}"; do wait "$pid"; done

  after=$(wc -l < "$PATHS_FILE")
  [ "$before" = "$after" ]
}
