#!/usr/bin/env bats
# Tests edge cases — fichiers corrompus
# Vérifie : comportement gracieux avec projects.md vide/corrompu, hub.json invalide, api-keys mal formaté

load helpers

setup() {
  common_setup

  export PROJECTS_FILE="$TEST_DIR/projects.md"
  export PATHS_FILE="$TEST_DIR/paths.local.md"
  export API_KEYS_FILE="$TEST_DIR/api-keys.local.md"
  export HUB_CONFIG="$TEST_DIR/hub.json"

  SCRIPT_DIR="$BATS_TEST_DIRNAME/../scripts"
  source "$SCRIPT_DIR/common.sh"
}

teardown() {
  common_teardown
}

# ── projects.md corrompu ──────────────────────────────────────────────────────

@test "corruption : projects.md vide → get_project_path retourne vide" {
  : > "$PROJECTS_FILE"
  : > "$PATHS_FILE"
  local path
  path=$(get_project_path "ANY-PROJ" 2>/dev/null || echo "")
  [ -z "$path" ]
}

@test "corruption : projects.md absent → get_project_path retourne vide" {
  rm -f "$PROJECTS_FILE"
  : > "$PATHS_FILE"
  local path
  path=$(get_project_path "ANY-PROJ" 2>/dev/null || echo "")
  [ -z "$path" ]
}

@test "corruption : projects.md avec contenu binaire → ne crashe pas" {
  printf '\x00\x01\x02\xFF\xFE' > "$PROJECTS_FILE"
  : > "$PATHS_FILE"
  run bash -c '
    source "$1/common.sh"
    get_project_path "ANY-PROJ" 2>/dev/null || true
  ' _ "$SCRIPT_DIR"
  # Ne doit pas retourner de code catastrophique (>125)
  [ "$status" -lt 126 ]
}

@test "corruption : projects.md avec encoding mixte → ne crashe pas" {
  printf '## PROJ-OK\n- Nom : Test\néàü\xFF\n' > "$PROJECTS_FILE"
  echo "PROJ-OK=$TEST_DIR/proj" >> "$PATHS_FILE"
  run bash -c '
    source "$1/common.sh"
    get_project_path "PROJ-OK" 2>/dev/null || echo ""
  ' _ "$SCRIPT_DIR"
  [ "$status" -lt 126 ]
}

# ── paths.local.md corrompu ───────────────────────────────────────────────────

@test "corruption : paths.local.md vide → get_project_path retourne vide" {
  cat > "$PROJECTS_FILE" <<'EOF'
# Registre

## TEST-PROJ
- Nom : Test
- Stack : Node.js
- Board Beads : TEST-PROJ
- Tracker : none
- Labels : test
- Agents : all
EOF
  : > "$PATHS_FILE"
  local path
  path=$(get_project_path "TEST-PROJ" 2>/dev/null || echo "")
  [ -z "$path" ]
}

@test "corruption : paths.local.md absent → get_project_path retourne vide" {
  cat > "$PROJECTS_FILE" <<'EOF'
# Registre

## TEST-PROJ
- Nom : Test
- Stack : Node.js
- Board Beads : TEST-PROJ
- Tracker : none
- Labels : test
- Agents : all
EOF
  rm -f "$PATHS_FILE"
  local path
  path=$(get_project_path "TEST-PROJ" 2>/dev/null || echo "")
  [ -z "$path" ]
}

@test "corruption : paths.local.md mal formaté → ne crashe pas" {
  printf 'pas=un=chemin=valide\n===\nfoo bar baz\n' > "$PATHS_FILE"
  run bash -c '
    source "$1/common.sh"
    get_project_path "ANY" 2>/dev/null || true
  ' _ "$SCRIPT_DIR"
  [ "$status" -lt 126 ]
}

# ── hub.json invalide ─────────────────────────────────────────────────────────

@test "corruption : hub.json vide → common.sh se charge sans crash" {
  : > "$HUB_CONFIG"
  run bash -c 'source "$1/common.sh" && echo "ok"' _ "$SCRIPT_DIR"
  [[ "$output" =~ "ok" ]]
}

@test "corruption : hub.json JSON invalide → common.sh se charge sans crash" {
  echo "{ invalid json {{" > "$HUB_CONFIG"
  run bash -c 'source "$1/common.sh" && echo "ok"' _ "$SCRIPT_DIR"
  [[ "$output" =~ "ok" ]]
}

@test "corruption : hub.json absent → common.sh se charge sans crash" {
  rm -f "$HUB_CONFIG"
  run bash -c 'source "$1/common.sh" && echo "ok"' _ "$SCRIPT_DIR"
  [[ "$output" =~ "ok" ]]
}

# ── api-keys.local.md mal formaté ────────────────────────────────────────────

@test "corruption : api-keys mal formaté → api_keys_entry_exists ne crashe pas" {
  printf 'pas|un|format|valide\n||\n\x00' > "$API_KEYS_FILE"
  cat > "$PROJECTS_FILE" <<'EOF'
# Registre

## TEST-PROJ
- Nom : Test
- Stack : Node.js
- Board Beads : TEST-PROJ
- Tracker : none
- Labels : test
- Agents : all
EOF
  run bash -c '
    source "$1/common.sh"
    api_keys_entry_exists "TEST-PROJ" 2>/dev/null || true
    echo "survived"
  ' _ "$SCRIPT_DIR"
  [[ "$output" =~ "survived" ]]
}

@test "corruption : api-keys vide → api_keys_entry_exists retourne false" {
  : > "$API_KEYS_FILE"
  cat > "$PROJECTS_FILE" <<'EOF'
# Registre

## TEST-PROJ
- Nom : Test
- Stack : Node.js
- Board Beads : TEST-PROJ
- Tracker : none
- Labels : test
- Agents : all
EOF
  run bash -c '
    source "$1/common.sh"
    api_keys_entry_exists "TEST-PROJ" && echo "found" || echo "not found"
  ' _ "$SCRIPT_DIR"
  [[ "$output" =~ "not found" ]]
}
