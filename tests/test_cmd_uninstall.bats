#!/usr/bin/env bats
# Tests pour scripts/cmd-uninstall.sh
# Vérifie : délégation à uninstall.sh (mock), code de sortie

load helpers

setup() {
  common_setup

  export HUB_DIR="$TEST_DIR/hub"
  export HUB_CONFIG="$TEST_DIR/hub.json"
  mkdir -p "$HUB_DIR"
  printf '{"version":"1.0.0","default_target":"opencode","active_targets":["opencode"],"cli":{"language":"fr"}}\n' \
    > "$HUB_CONFIG"

  CMD_UNINSTALL="$BATS_TEST_DIRNAME/../scripts/cmd-uninstall.sh"

  # Créer un mock uninstall.sh dans HUB_DIR
  UNINSTALL_LOG="$TEST_DIR/uninstall_calls.log"
  export UNINSTALL_LOG
  : > "$UNINSTALL_LOG"

  cat > "$HUB_DIR/uninstall.sh" <<'EOF'
#!/bin/bash
echo "uninstall called" >> "$UNINSTALL_LOG"
exit 0
EOF
  chmod +x "$HUB_DIR/uninstall.sh"
}

teardown() {
  common_teardown
}

# ── Délégation ────────────────────────────────────────────────────────────────

@test "uninstall : délègue l'exécution à HUB_DIR/uninstall.sh" {
  run bash "$CMD_UNINSTALL"
  [ "$status" -eq 0 ]
  grep -q "uninstall called" "$UNINSTALL_LOG"
}

@test "uninstall : code de sortie = code de uninstall.sh (succès)" {
  run bash "$CMD_UNINSTALL"
  [ "$status" -eq 0 ]
}

@test "uninstall : code de sortie = code de uninstall.sh (échec)" {
  # Remplacer le mock par un qui retourne 1
  cat > "$HUB_DIR/uninstall.sh" <<'EOF'
#!/bin/bash
exit 1
EOF
  chmod +x "$HUB_DIR/uninstall.sh"
  run bash "$CMD_UNINSTALL"
  [ "$status" -eq 1 ]
}

@test "uninstall : appelle uninstall.sh une seule fois" {
  run bash "$CMD_UNINSTALL"
  local calls
  calls=$(grep -c "uninstall called" "$UNINSTALL_LOG" 2>/dev/null || echo 0)
  [ "$calls" -eq 1 ]
}
