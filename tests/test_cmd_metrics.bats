#!/usr/bin/env bats
# Tests pour scripts/cmd-metrics.sh et scripts/lib/metrics.sh

setup() {
  TEST_DIR="$(mktemp -d)"

  export PROJECTS_FILE="$TEST_DIR/projects.md"
  export PATHS_FILE="$TEST_DIR/paths.local.md"
  export API_KEYS_FILE="$TEST_DIR/api-keys.local.md"

  # Isoler HUB_CONFIG
  export HUB_CONFIG="$TEST_DIR/hub.json"
  printf '{"version":"1.0.0","default_target":"opencode","active_targets":["opencode"],"cli":{"language":"fr"}}\n' \
    > "$HUB_CONFIG"

  CMD_METRICS="$BATS_TEST_DIRNAME/../scripts/cmd-metrics.sh"
  LIB_METRICS="$BATS_TEST_DIRNAME/../scripts/lib/metrics.sh"
  COMMON_SH="$BATS_TEST_DIRNAME/../scripts/common.sh"

  # Créer un projet factice avec .opencode/
  mkdir -p "$TEST_DIR/fake-project/.opencode"
  export _METRICS_DIR="$TEST_DIR/fake-project/.opencode"
  export _METRICS_FILE="$_METRICS_DIR/metrics.jsonl"

  # Fichiers de config de base
  cat > "$PROJECTS_FILE" <<'PROJEOF'
# Registre de test

## TEST-PROJ
- Nom : Projet Test
- Stack : Node.js
- Agents : all
PROJEOF

  cat > "$PATHS_FILE" <<EOF
TEST-PROJ=$TEST_DIR/fake-project
EOF

  : > "$API_KEYS_FILE"
}

teardown() {
  unset HUB_CONFIG
  unset _METRICS_DIR
  unset _METRICS_FILE
  rm -rf "$TEST_DIR"
}

# ══════════════════════════════════════════════════════════════════════════════
# Tests cmd-metrics.sh — Cas fichier absent
# ══════════════════════════════════════════════════════════════════════════════

@test "cmd-metrics : affiche message informatif si fichier metrics absent" {
  # S'assurer qu'aucun fichier metrics n'existe
  rm -f "$_METRICS_FILE"

  run bash -c "cd '$TEST_DIR/fake-project' && bash '$CMD_METRICS'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fichier de métriques non trouvé"* ]] || [[ "$output" == *"metrics file not found"* ]] || [[ "$output" == *"non trouvé"* ]]
}

@test "cmd-metrics : exit 0 même si fichier metrics absent" {
  rm -f "$_METRICS_FILE"

  run bash -c "cd '$TEST_DIR/fake-project' && bash '$CMD_METRICS'"
  [ "$status" -eq 0 ]
}

# ══════════════════════════════════════════════════════════════════════════════
# Tests cmd-metrics.sh — Cas fichier vide
# ══════════════════════════════════════════════════════════════════════════════

@test "cmd-metrics : gère le fichier metrics vide" {
  mkdir -p "$_METRICS_DIR"
  : > "$_METRICS_FILE"

  run bash -c "cd '$TEST_DIR/fake-project' && bash '$CMD_METRICS'"
  [ "$status" -eq 0 ]
  # Devrait afficher 0 tickets ou un message indiquant pas de données
  [[ "$output" == *"0"* ]] || [[ "$output" == *"Aucune"* ]] || [[ "$output" == *"—"* ]]
}

# ══════════════════════════════════════════════════════════════════════════════
# Tests cmd-metrics.sh — Cas nominal avec données
# ══════════════════════════════════════════════════════════════════════════════

@test "cmd-metrics : affiche les métriques avec données" {
  mkdir -p "$_METRICS_DIR"
  cat > "$_METRICS_FILE" <<'EOF'
{"timestamp":"2026-01-01T10:00:00Z","event":"ticket_complete","ticket_id":"bd-1","agent":"developer-backend","duration_seconds":600}
{"timestamp":"2026-01-01T11:00:00Z","event":"ticket_complete","ticket_id":"bd-2","agent":"developer-frontend","duration_seconds":900}
{"timestamp":"2026-01-01T12:00:00Z","event":"review_cycle","ticket_id":"bd-1","cycle":1}
{"timestamp":"2026-01-01T12:30:00Z","event":"correction","ticket_id":"bd-1","reason":"lint errors"}
EOF

  run bash -c "cd '$TEST_DIR/fake-project' && bash '$CMD_METRICS'"
  [ "$status" -eq 0 ]
  # Vérifie que l'affichage contient les statistiques
  [[ "$output" == *"2"* ]]  # 2 tickets complétés
}

@test "cmd-metrics : affiche l'en-tête avec titre" {
  mkdir -p "$_METRICS_DIR"
  echo '{"timestamp":"2026-01-01T10:00:00Z","event":"ticket_complete","ticket_id":"bd-1","duration_seconds":300}' > "$_METRICS_FILE"

  run bash -c "cd '$TEST_DIR/fake-project' && bash '$CMD_METRICS'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"triques"* ]] || [[ "$output" == *"etrics"* ]]  # Métriques ou Metrics
}

@test "cmd-metrics : affiche le nombre de tickets complétés" {
  mkdir -p "$_METRICS_DIR"
  cat > "$_METRICS_FILE" <<'EOF'
{"timestamp":"2026-01-01T10:00:00Z","event":"ticket_complete","ticket_id":"bd-1","duration_seconds":600}
{"timestamp":"2026-01-01T11:00:00Z","event":"ticket_complete","ticket_id":"bd-2","duration_seconds":900}
{"timestamp":"2026-01-01T12:00:00Z","event":"ticket_complete","ticket_id":"bd-3","duration_seconds":300}
EOF

  run bash -c "cd '$TEST_DIR/fake-project' && bash '$CMD_METRICS'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"3"* ]]  # 3 tickets complétés
}

@test "cmd-metrics : affiche les raisons de correction" {
  mkdir -p "$_METRICS_DIR"
  cat > "$_METRICS_FILE" <<'EOF'
{"timestamp":"2026-01-01T10:00:00Z","event":"ticket_complete","ticket_id":"bd-1","duration_seconds":600}
{"timestamp":"2026-01-01T12:30:00Z","event":"correction","ticket_id":"bd-1","reason":"lint errors"}
{"timestamp":"2026-01-01T13:00:00Z","event":"correction","ticket_id":"bd-2","reason":"lint errors"}
{"timestamp":"2026-01-01T13:30:00Z","event":"correction","ticket_id":"bd-3","reason":"test failures"}
EOF

  run bash -c "cd '$TEST_DIR/fake-project' && bash '$CMD_METRICS'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lint errors"* ]]
}

# ══════════════════════════════════════════════════════════════════════════════
# Tests lib/metrics.sh — Fonctions d'agrégation
# ══════════════════════════════════════════════════════════════════════════════

@test "metrics_count_completed : retourne 0 si fichier absent" {
  rm -f "$_METRICS_FILE"

  run bash -c "
    source '$COMMON_SH'
    source '$LIB_METRICS'
    _METRICS_FILE='$_METRICS_FILE'
    metrics_count_completed
  "
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "metrics_count_completed : compte correctement les tickets" {
  mkdir -p "$_METRICS_DIR"
  cat > "$_METRICS_FILE" <<'EOF'
{"timestamp":"2026-01-01T10:00:00Z","event":"ticket_complete","ticket_id":"bd-1","duration_seconds":600}
{"timestamp":"2026-01-01T11:00:00Z","event":"ticket_complete","ticket_id":"bd-2","duration_seconds":900}
{"timestamp":"2026-01-01T12:00:00Z","event":"ticket_start","ticket_id":"bd-3"}
EOF

  run bash -c "
    source '$COMMON_SH'
    source '$LIB_METRICS'
    _METRICS_FILE='$_METRICS_FILE'
    metrics_count_completed
  "
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "metrics_avg_duration : retourne 0 si fichier absent" {
  rm -f "$_METRICS_FILE"

  run bash -c "
    source '$COMMON_SH'
    source '$LIB_METRICS'
    _METRICS_FILE='$_METRICS_FILE'
    metrics_avg_duration
  "
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "metrics_avg_duration : calcule la moyenne correctement" {
  mkdir -p "$_METRICS_DIR"
  cat > "$_METRICS_FILE" <<'EOF'
{"timestamp":"2026-01-01T10:00:00Z","event":"ticket_complete","ticket_id":"bd-1","duration_seconds":600}
{"timestamp":"2026-01-01T11:00:00Z","event":"ticket_complete","ticket_id":"bd-2","duration_seconds":900}
EOF

  run bash -c "
    source '$COMMON_SH'
    source '$LIB_METRICS'
    _METRICS_FILE='$_METRICS_FILE'
    metrics_avg_duration
  "
  [ "$status" -eq 0 ]
  [ "$output" = "750" ]  # (600 + 900) / 2 = 750
}

@test "metrics_avg_review_cycles : retourne 0 si fichier absent" {
  rm -f "$_METRICS_FILE"

  run bash -c "
    source '$COMMON_SH'
    source '$LIB_METRICS'
    _METRICS_FILE='$_METRICS_FILE'
    metrics_avg_review_cycles
  "
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "metrics_avg_review_cycles : calcule la moyenne correctement" {
  mkdir -p "$_METRICS_DIR"
  cat > "$_METRICS_FILE" <<'EOF'
{"timestamp":"2026-01-01T10:00:00Z","event":"ticket_complete","ticket_id":"bd-1","duration_seconds":600}
{"timestamp":"2026-01-01T10:30:00Z","event":"review_cycle","ticket_id":"bd-1","cycle":1}
{"timestamp":"2026-01-01T11:00:00Z","event":"ticket_complete","ticket_id":"bd-2","duration_seconds":900}
{"timestamp":"2026-01-01T11:30:00Z","event":"review_cycle","ticket_id":"bd-2","cycle":1}
{"timestamp":"2026-01-01T11:45:00Z","event":"review_cycle","ticket_id":"bd-2","cycle":2}
EOF

  run bash -c "
    source '$COMMON_SH'
    source '$LIB_METRICS'
    _METRICS_FILE='$_METRICS_FILE'
    metrics_avg_review_cycles
  "
  [ "$status" -eq 0 ]
  [ "$output" = "1.5" ]  # 3 review_cycles / 2 tickets = 1.5
}

@test "metrics_top_corrections : retourne vide si fichier absent" {
  rm -f "$_METRICS_FILE"

  run bash -c "
    source '$COMMON_SH'
    source '$LIB_METRICS'
    _METRICS_FILE='$_METRICS_FILE'
    metrics_top_corrections
  "
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "metrics_top_corrections : retourne le top des raisons" {
  mkdir -p "$_METRICS_DIR"
  cat > "$_METRICS_FILE" <<'EOF'
{"timestamp":"2026-01-01T12:00:00Z","event":"correction","ticket_id":"bd-1","reason":"lint errors"}
{"timestamp":"2026-01-01T12:30:00Z","event":"correction","ticket_id":"bd-2","reason":"lint errors"}
{"timestamp":"2026-01-01T13:00:00Z","event":"correction","ticket_id":"bd-3","reason":"lint errors"}
{"timestamp":"2026-01-01T13:30:00Z","event":"correction","ticket_id":"bd-4","reason":"test failures"}
{"timestamp":"2026-01-01T14:00:00Z","event":"correction","ticket_id":"bd-5","reason":"test failures"}
{"timestamp":"2026-01-01T14:30:00Z","event":"correction","ticket_id":"bd-6","reason":"type errors"}
EOF

  run bash -c "
    source '$COMMON_SH'
    source '$LIB_METRICS'
    _METRICS_FILE='$_METRICS_FILE'
    metrics_top_corrections 3
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"lint errors"* ]]
  [[ "$output" == *"test failures"* ]]
}

@test "metrics_format_duration : formate correctement les secondes" {
  run bash -c "
    source '$COMMON_SH'
    source '$LIB_METRICS'
    metrics_format_duration 45
  "
  [ "$status" -eq 0 ]
  [ "$output" = "45s" ]
}

@test "metrics_format_duration : formate correctement les minutes" {
  run bash -c "
    source '$COMMON_SH'
    source '$LIB_METRICS'
    metrics_format_duration 125
  "
  [ "$status" -eq 0 ]
  [ "$output" = "2m 5s" ]
}

@test "metrics_format_duration : formate correctement les heures" {
  run bash -c "
    source '$COMMON_SH'
    source '$LIB_METRICS'
    metrics_format_duration 3665
  "
  [ "$status" -eq 0 ]
  [ "$output" = "1h 1m 5s" ]
}

@test "metrics_format_duration : gère 0 secondes" {
  run bash -c "
    source '$COMMON_SH'
    source '$LIB_METRICS'
    metrics_format_duration 0
  "
  [ "$status" -eq 0 ]
  [ "$output" = "0s" ]
}

@test "metrics_format_duration : gère valeur vide" {
  run bash -c "
    source '$COMMON_SH'
    source '$LIB_METRICS'
    metrics_format_duration ''
  "
  [ "$status" -eq 0 ]
  [ "$output" = "0s" ]
}
