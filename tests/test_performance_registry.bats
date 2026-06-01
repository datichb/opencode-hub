#!/usr/bin/env bats
# Tests de performance — scalabilité du registre de projets
# Vérifie : lecture rapide avec 100+ projets, pas de dégradation O(n²)

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

  # Générer un registre de 100 projets
  {
    echo "# Registre de performance"
    echo ""
    for i in $(seq 1 100); do
      local id
      id=$(printf "PROJ-%03d" "$i")
      echo "## $id"
      echo "- Nom : Project $i"
      echo "- Stack : Node.js"
      echo "- Board Beads : $id"
      echo "- Tracker : none"
      echo "- Labels : perf"
      echo "- Agents : all"
      echo ""
      echo "$id=$TEST_DIR/proj-$i" >> "$PATHS_FILE"
    done
  } > "$PROJECTS_FILE"

  : > "$API_KEYS_FILE"
}

teardown() {
  common_teardown
}

# ── Lecture scalable ──────────────────────────────────────────────────────────

@test "performance registry : lecture de 100 projets en moins de 10s" {
  local start end elapsed
  start=$(date +%s%N 2>/dev/null || date +%s)
  for i in $(seq 1 100); do
    local id
    id=$(printf "PROJ-%03d" "$i")
    get_project_path "$id" > /dev/null
  done
  end=$(date +%s%N 2>/dev/null || date +%s)
  if [[ "$start" =~ [0-9]{10,} ]]; then
    elapsed=$(( (end - start) / 1000000 ))
    [ "$elapsed" -lt 10000 ]
  else
    elapsed=$(( end - start ))
    [ "$elapsed" -lt 10 ]
  fi
}

@test "performance registry : get_project_path sur PROJ-050 retourne le bon chemin" {
  local path
  path=$(get_project_path "PROJ-050")
  [ "$path" = "$TEST_DIR/proj-50" ]
}

@test "performance registry : get_project_path sur PROJ-100 retourne le bon chemin" {
  local path
  path=$(get_project_path "PROJ-100")
  [ "$path" = "$TEST_DIR/proj-100" ]
}

@test "performance registry : get_project_tracker sur 50 projets en moins de 15s" {
  local start end elapsed
  start=$(date +%s%N 2>/dev/null || date +%s)
  for i in $(seq 1 50); do
    local id
    id=$(printf "PROJ-%03d" "$i")
    get_project_tracker "$id" > /dev/null
  done
  end=$(date +%s%N 2>/dev/null || date +%s)
  if [[ "$start" =~ [0-9]{10,} ]]; then
    elapsed=$(( (end - start) / 1000000 ))
    [ "$elapsed" -lt 15000 ]
  else
    elapsed=$(( end - start ))
    [ "$elapsed" -lt 15 ]
  fi
}

@test "performance registry : cmd-status --short avec 100 projets en moins de 15s" {
  local start end elapsed
  start=$(date +%s%N 2>/dev/null || date +%s)
  run bash "$SCRIPT_DIR/cmd-status.sh" --short
  end=$(date +%s%N 2>/dev/null || date +%s)
  [ "$status" -eq 0 ]
  if [[ "$start" =~ [0-9]{10,} ]]; then
    elapsed=$(( (end - start) / 1000000 ))
    [ "$elapsed" -lt 15000 ]
  else
    elapsed=$(( end - start ))
    [ "$elapsed" -lt 15 ]
  fi
}

@test "performance registry : 100 projets tous listés dans cmd-status" {
  run bash "$SCRIPT_DIR/cmd-status.sh" --short
  [ "$status" -eq 0 ]
  [[ "$output" =~ "PROJ-001" ]]
  [[ "$output" =~ "PROJ-050" ]]
  [[ "$output" =~ "PROJ-100" ]]
}
