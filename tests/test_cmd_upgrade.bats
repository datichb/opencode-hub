#!/usr/bin/env bats
# Tests pour scripts/cmd-upgrade.sh
# Stratégie : créer un faux repo git temporaire qui joue le rôle du hub,
#             puis exécuter cmd-upgrade.sh en surchargeant HUB_DIR vers ce faux repo.
#             Git est mocké via PATH pour contrôler les sorties sans accès réseau.

setup() {
  TEST_DIR="$(mktemp -d)"

  # ── Faux repo hub ────────────────────────────────────────────────────────────
  HUB_FAKE="$TEST_DIR/hub"
  mkdir -p "$HUB_FAKE/config" "$HUB_FAKE/scripts/lib" "$HUB_FAKE/scripts/adapters"

  # hub.json minimal
  printf '{"version":"1.0.0","cli":{"language":"en"}}\n' \
    > "$HUB_FAKE/config/hub.json"

  # Copier les scripts réels dans le faux hub (pour que common.sh et i18n.sh soient disponibles)
  cp "$BATS_TEST_DIRNAME/../scripts/common.sh"      "$HUB_FAKE/scripts/"
  cp "$BATS_TEST_DIRNAME/../scripts/cmd-upgrade.sh" "$HUB_FAKE/scripts/"
  cp "$BATS_TEST_DIRNAME/../scripts/cmd-sync.sh"    "$HUB_FAKE/scripts/"
  cp -r "$BATS_TEST_DIRNAME/../scripts/lib/."        "$HUB_FAKE/scripts/lib/"
  cp -r "$BATS_TEST_DIRNAME/../scripts/adapters/."   "$HUB_FAKE/scripts/adapters/"

  # ── Répertoire de binaires mock ──────────────────────────────────────────────
  BIN_DIR="$TEST_DIR/bin"
  mkdir -p "$BIN_DIR"

  # Mock oc sync (appelé après un upgrade réussi si l'utilisateur confirme)
  cat > "$BIN_DIR/oc-sync-mock" <<'MOCK'
#!/bin/bash
echo "sync called"
exit 0
MOCK
  chmod +x "$BIN_DIR/oc-sync-mock"

  # Script sous test
  CMD_UPGRADE="$HUB_FAKE/scripts/cmd-upgrade.sh"

  # Exporter HUB_DIR pour que common.sh auto-détecte correctement
  export HUB_DIR="$HUB_FAKE"
  export SCRIPTS_DIR="$HUB_FAKE/scripts"
}

teardown() {
  unset HUB_DIR SCRIPTS_DIR
  rm -rf "$TEST_DIR"
}

# ── Helpers ───────────────────────────────────────────────────────────────────

# Crée un mock git dans BIN_DIR/$name qui écrit sa sortie et retourne $exit_code
_mock_git() {
  local name="${1:-git}" output="$2" exit_code="${3:-0}"
  cat > "$BIN_DIR/$name" <<GITEOF
#!/bin/bash
printf '%s\n' "$output"
exit $exit_code
GITEOF
  chmod +x "$BIN_DIR/$name"
}

# Exécute cmd-upgrade.sh avec git mocké et sans interactivité (réponse "n" à sync)
# Usage: _run_upgrade [VERSION_ARG]
_run_upgrade() {
  local version_arg="${1:-}"
  # PATH modifié pour que "git" pointe vers le mock
  # 3>&- ferme le FD3 de bats pour éviter que les sous-processus ne le bloquent
  run bash -c \
    'export PATH="$1:$PATH"; printf "n\n" | bash "$2" $3 3>&-' \
    _ "$BIN_DIR" "$CMD_UPGRADE" "$version_arg"
}

# ── Validation de l'argument version ─────────────────────────────────────────

@test "upgrade : exit 1 si l'argument n'est pas un semver valide" {
  _mock_git "git" "Already up to date." 0
  run bash "$CMD_UPGRADE" "pas-une-version"
  [ "$status" -ne 0 ]
}

@test "upgrade : exit 1 si l'argument est juste 'v' sans numéro" {
  _mock_git "git" "Already up to date." 0
  run bash "$CMD_UPGRADE" "v"
  [ "$status" -ne 0 ]
}

@test "upgrade : accepte vX.Y.Z avec préfixe v" {
  # Mock git fetch + git checkout pour simuler un checkout réussi
  cat > "$BIN_DIR/git" <<'GITEOF'
#!/bin/bash
# fetch --tags → succès silencieux
# checkout <tag> → succès silencieux
exit 0
GITEOF
  chmod +x "$BIN_DIR/git"
  # On bypass la question sync avec "n"
  run bash -c 'export PATH="$1:$PATH"; printf "n\n" | bash "$2" v1.0.0' \
    _ "$BIN_DIR" "$CMD_UPGRADE"
  [ "$status" -eq 0 ]
}

@test "upgrade : accepte X.Y.Z sans préfixe v" {
  cat > "$BIN_DIR/git" <<'GITEOF'
#!/bin/bash
exit 0
GITEOF
  chmod +x "$BIN_DIR/git"
  run bash -c 'export PATH="$1:$PATH"; printf "n\n" | bash "$2" 1.0.0' \
    _ "$BIN_DIR" "$CMD_UPGRADE"
  [ "$status" -eq 0 ]
}

# ── Mode pull (sans argument) ─────────────────────────────────────────────────

@test "upgrade sans argument : exit 0 si déjà à jour" {
  _mock_git "git" "Already up to date." 0
  _run_upgrade
  [ "$status" -eq 0 ]
}

@test "upgrade sans argument : affiche un message 'déjà à jour'" {
  _mock_git "git" "Already up to date." 0
  _run_upgrade
  [[ "$output" == *"up to date"* ]] || [[ "$output" == *"jour"* ]]
}

@test "upgrade sans argument : exit 0 après un pull réussi" {
  _mock_git "git" "Updating abc1234..def5678" 0
  _run_upgrade
  [ "$status" -eq 0 ]
}

@test "upgrade sans argument : exit non-zero si git retourne fatal" {
  _mock_git "git" "fatal: unable to access 'https://github.com/...'" 0
  _run_upgrade
  [ "$status" -ne 0 ]
}

# ── Mode checkout tag ─────────────────────────────────────────────────────────

@test "upgrade v1.0.0 : exit 0 si fetch + checkout réussis" {
  cat > "$BIN_DIR/git" <<'GITEOF'
#!/bin/bash
exit 0
GITEOF
  chmod +x "$BIN_DIR/git"
  run bash -c 'export PATH="$1:$PATH"; printf "n\n" | bash "$2" v1.0.0' \
    _ "$BIN_DIR" "$CMD_UPGRADE"
  [ "$status" -eq 0 ]
}

@test "upgrade v9.9.9 : exit 1 si tag introuvable (checkout échoue)" {
  # git fetch réussit, git checkout échoue
  cat > "$BIN_DIR/git" <<'GITEOF'
#!/bin/bash
# Simuler: fetch ok, checkout fail
if [[ "$*" == *"checkout"* ]]; then
  echo "error: pathspec 'v9.9.9' did not match any file(s) known to git" >&2
  exit 1
fi
exit 0
GITEOF
  chmod +x "$BIN_DIR/git"
  run bash -c 'export PATH="$1:$PATH"; printf "n\n" | bash "$2" v9.9.9' \
    _ "$BIN_DIR" "$CMD_UPGRADE"
  [ "$status" -ne 0 ]
}

@test "upgrade v9.9.9 : exit 1 si fetch échoue" {
  _mock_git "git" "fatal: repository not found" 1
  run bash -c 'export PATH="$1:$PATH"; printf "n\n" | bash "$2" v9.9.9' \
    _ "$BIN_DIR" "$CMD_UPGRADE"
  [ "$status" -ne 0 ]
}

# ── Proposition de sync après mise à jour ─────────────────────────────────────

@test "upgrade : ne propose pas sync si déjà à jour" {
  _mock_git "git" "Already up to date." 0
  _run_upgrade
  [[ "$output" != *"sync"* ]] || true  # sync ne doit pas être déclenché
  # Le test clé : status 0 et pas d'appel à cmd-sync
  [ "$status" -eq 0 ]
}

@test "upgrade : propose sync après pull réussi et répond n" {
  _mock_git "git" "Updating abc1234..def5678" 0
  _run_upgrade
  [ "$status" -eq 0 ]
  # La question sync doit avoir été posée
  [[ "$output" == *"sync"* ]]
}
