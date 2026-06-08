#!/usr/bin/env bats
# Tests unitaires pour scripts/lib/mcp-deploy.sh
# Fonctions testées : check_and_build_mcp, deploy_mcp_servers, configure_mcp_in_project

load helpers

setup() {
  common_setup
  
  # Sourcer common.sh pour avoir les variables
  export SCRIPT_DIR="$BATS_TEST_DIRNAME/../scripts"
  export LIB_DIR="$SCRIPT_DIR/lib"
  export HUB_DIR="$BATS_TEST_DIRNAME/.."
  source "$SCRIPT_DIR/common.sh"

  # Sourcer les libs nécessaires (services.sh requis par mcp-deploy.sh)
  export SERVICES_FILE="$TEST_DIR/services.json"
  cat > "$SERVICES_FILE" <<'EOF'
{
  "services": {
    "figma": {
      "label": "Figma",
      "mcp_server": "figma-mcp",
      "credentials": [
        {"key": "FIGMA_PERSONAL_ACCESS_TOKEN", "secret": true, "required": true},
        {"key": "FIGMA_TEAM_ID", "secret": false, "required": true}
      ]
    },
    "gitlab": {
      "label": "GitLab",
      "mcp_server": "gitlab-mcp",
      "credentials": [
        {"key": "GITLAB_PERSONAL_ACCESS_TOKEN", "secret": true, "required": true},
        {"key": "GITLAB_BASE_URL", "secret": false, "required": false}
      ]
    }
  }
}
EOF
  export OPENCODE_GLOBAL_CONFIG="$TEST_DIR/services-env.json"
  source "$SCRIPT_DIR/lib/services.sh"

  # Sourcer le module
  source "$BATS_TEST_DIRNAME/../scripts/lib/mcp-deploy.sh"
  
  # Mock des fonctions log
  mock_log_functions
  
  # Créer un faux hub avec servers
  export TEST_HUB_DIR="$TEST_DIR/hub"
  export HUB_DIR="$TEST_HUB_DIR"
  mkdir -p "$TEST_HUB_DIR/servers/figma-mcp"
  mkdir -p "$TEST_HUB_DIR/scripts"
}

teardown() {
  common_teardown
}

# ── check_and_build_mcp ─────────────────────────────────────────────────────

@test "check_and_build_mcp : retourne 0 si MCP à jour" {
  # Mock check-mcp.sh qui dit que tout est OK
  cat > "$HUB_DIR/scripts/check-mcp.sh" <<'EOF'
#!/bin/bash
echo "All MCP servers are up to date"
exit 0
EOF
  chmod +x "$HUB_DIR/scripts/check-mcp.sh"
  
  run check_and_build_mcp
  [ "$status" -eq 0 ]
}

@test "check_and_build_mcp : propose build si MCP obsolète" {
  # Mock check-mcp.sh qui dit qu'il faut builder
  cat > "$HUB_DIR/scripts/check-mcp.sh" <<'EOF'
#!/bin/bash
echo "Some servers need to be built"
exit 0
EOF
  chmod +x "$HUB_DIR/scripts/check-mcp.sh"
  
  # Mock build-mcp.sh
  cat > "$HUB_DIR/scripts/build-mcp.sh" <<'EOF'
#!/bin/bash
echo "Building MCP servers..."
exit 0
EOF
  chmod +x "$HUB_DIR/scripts/build-mcp.sh"
  
  # Mock _prompt pour accepter automatiquement
  _prompt() {
    eval "$1='Y'"
  }
  export -f _prompt
  
  run check_and_build_mcp
  [ "$status" -eq 0 ]
}

@test "check_and_build_mcp : skip build si utilisateur refuse" {
  # Mock check-mcp.sh
  cat > "$HUB_DIR/scripts/check-mcp.sh" <<'EOF'
#!/bin/bash
echo "Some servers need to be built"
exit 0
EOF
  chmod +x "$HUB_DIR/scripts/check-mcp.sh"
  
  # Mock _prompt pour refuser
  _prompt() {
    eval "$1='N'"
  }
  export -f _prompt
  
  run check_and_build_mcp
  [ "$status" -ne 0 ]
}

# ── deploy_mcp_servers ──────────────────────────────────────────────────────

@test "deploy_mcp_servers : crée dossier .opencode/servers" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir"
  
  deploy_mcp_servers "$deploy_dir"
  
  [ -d "$deploy_dir/.opencode/servers" ]
}

@test "deploy_mcp_servers : copie dist et package.json" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir"
  
  # Créer un serveur de test avec dist
  mkdir -p "$HUB_DIR/servers/test-server/dist"
  echo "console.log('test');" > "$HUB_DIR/servers/test-server/dist/index.js"
  cat > "$HUB_DIR/servers/test-server/package.json" <<'EOF'
{
  "name": "test-server",
  "version": "1.0.0"
}
EOF
  
  # Mock npm install
  npm() {
    return 0
  }
  export -f npm
  
  deploy_mcp_servers "$deploy_dir"
  
  [ -f "$deploy_dir/.opencode/servers/test-server/dist/index.js" ]
  [ -f "$deploy_dir/.opencode/servers/test-server/package.json" ]
}

@test "deploy_mcp_servers : skip serveur non buildé" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir"
  
  # Créer un serveur sans dist
  mkdir -p "$HUB_DIR/servers/unbuild-server"
  cat > "$HUB_DIR/servers/unbuild-server/package.json" <<'EOF'
{
  "name": "unbuild-server",
  "version": "1.0.0"
}
EOF
  
  deploy_mcp_servers "$deploy_dir"
  
  [ ! -d "$deploy_dir/.opencode/servers/unbuild-server" ]
}

@test "deploy_mcp_servers : déploie plusieurs serveurs" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir"
  
  # Créer 2 serveurs
  for srv in server1 server2; do
    mkdir -p "$HUB_DIR/servers/$srv/dist"
    echo "console.log('$srv');" > "$HUB_DIR/servers/$srv/dist/index.js"
    cat > "$HUB_DIR/servers/$srv/package.json" <<EOF
{
  "name": "$srv",
  "version": "1.0.0"
}
EOF
  done
  
  # Mock npm
  npm() {
    return 0
  }
  export -f npm
  
  deploy_mcp_servers "$deploy_dir"
  
  [ -d "$deploy_dir/.opencode/servers/server1" ]
  [ -d "$deploy_dir/.opencode/servers/server2" ]
}

@test "deploy_mcp_servers : gère erreur copie dist" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir"
  
  # Créer serveur mais dist en lecture seule
  mkdir -p "$HUB_DIR/servers/readonly-server/dist"
  echo "test" > "$HUB_DIR/servers/readonly-server/dist/index.js"
  cat > "$HUB_DIR/servers/readonly-server/package.json" <<'EOF'
{
  "name": "readonly-server"
}
EOF
  
  # Mock cp qui échoue
  cp() {
    if [[ "$*" == *"dist"* ]]; then
      return 1
    fi
    command cp "$@"
  }
  export -f cp
  
  run deploy_mcp_servers "$deploy_dir"
  [ "$status" -eq 0 ]  # Continue malgré l'erreur
}

@test "deploy_mcp_servers : retourne 0 si aucun serveur" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir"
  
  # Pas de serveurs dans hub
  rm -rf "$HUB_DIR/servers"/*
  
  run deploy_mcp_servers "$deploy_dir"
  [ "$status" -eq 0 ]
}

# ── configure_mcp_in_project ────────────────────────────────────────────────

@test "configure_mcp_in_project : skip si opencode.json absent" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir"
  
  run configure_mcp_in_project "$deploy_dir"
  [ "$status" -eq 0 ]
}

@test "configure_mcp_in_project : configure figma-mcp" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir/.opencode/servers/figma-mcp/dist"
  
  # Créer opencode.json minimal
  cat > "$deploy_dir/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json"
}
EOF
  
  # Mock jq
  which jq >/dev/null 2>&1 || skip "jq non disponible"
  
  configure_mcp_in_project "$deploy_dir"
  
  # Vérifier que figma-mcp est configuré avec le bon format (schéma opencode valide)
  run jq -r '.mcp["figma-mcp"].type' "$deploy_dir/opencode.json"
  [ "$output" = "local" ]

  run jq -r '.mcp["figma-mcp"].command[0]' "$deploy_dir/opencode.json"
  [ "$output" = "node" ]
  
  run jq -r '.mcp["figma-mcp"].command[1]' "$deploy_dir/opencode.json"
  [ "$output" = ".opencode/servers/figma-mcp/dist/index.js" ]
}

@test "configure_mcp_in_project : sauvegarde backup" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir/.opencode/servers/figma-mcp/dist"
  
  cat > "$deploy_dir/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json"
}
EOF
  
  which jq >/dev/null 2>&1 || skip "jq non disponible"
  
  configure_mcp_in_project "$deploy_dir"
  
  # Le backup est supprimé si succès
  [ ! -f "$deploy_dir/opencode.json.bak" ]
}

@test "configure_mcp_in_project : restaure backup si erreur jq" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir/.opencode/servers/figma-mcp/dist"
  
  local original_content='{"mcpServers":{},"original":true}'
  echo "$original_content" > "$deploy_dir/opencode.json"
  
  # Mock jq qui échoue
  jq() {
    return 1
  }
  export -f jq
  
  configure_mcp_in_project "$deploy_dir"
  
  # Le fichier original devrait être restauré avec son contenu original
  [ -f "$deploy_dir/opencode.json" ]
  run cat "$deploy_dir/opencode.json"
  [[ "$output" == *'"original":true'* ]]
}

@test "configure_mcp_in_project : ne configure pas serveurs non déployés" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir"
  
  cat > "$deploy_dir/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json"
}
EOF
  
  # Pas de serveurs déployés
  
  which jq >/dev/null 2>&1 || skip "jq non disponible"
  
  configure_mcp_in_project "$deploy_dir"
  
  # mcp ne doit pas contenir figma-mcp
  run jq -r '.mcp["figma-mcp"] // empty' "$deploy_dir/opencode.json"
  [ -z "$output" ]
}

# ── Intégration ─────────────────────────────────────────────────────────────

@test "Intégration : workflow complet déploiement MCP" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir"
  
  # Préparer serveur
  mkdir -p "$HUB_DIR/servers/figma-mcp/dist"
  echo "console.log('figma');" > "$HUB_DIR/servers/figma-mcp/dist/index.js"
  cat > "$HUB_DIR/servers/figma-mcp/package.json" <<'EOF'
{
  "name": "figma-mcp",
  "version": "1.0.0"
}
EOF
  
  # Créer opencode.json
  cat > "$deploy_dir/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json"
}
EOF
  
  # Mock npm
  npm() {
    return 0
  }
  export -f npm
  
  which jq >/dev/null 2>&1 || skip "jq non disponible"
  
  # Déployer
  deploy_mcp_servers "$deploy_dir"
  
  # Configurer
  configure_mcp_in_project "$deploy_dir"
  
  # Vérifier déploiement
  [ -f "$deploy_dir/.opencode/servers/figma-mcp/dist/index.js" ]
  
  # Vérifier configuration : format schéma opencode valide
  run jq -r '.mcp["figma-mcp"].type' "$deploy_dir/opencode.json"
  [ "$output" = "local" ]

  run jq -r '.mcp["figma-mcp"].command[0]' "$deploy_dir/opencode.json"
  [ "$output" = "node" ]
}

@test "Intégration : déploiement sans opencode.json existant" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir"
  
  # Préparer serveur
  mkdir -p "$HUB_DIR/servers/test-mcp/dist"
  echo "test" > "$HUB_DIR/servers/test-mcp/dist/index.js"
  cat > "$HUB_DIR/servers/test-mcp/package.json" <<'EOF'
{
  "name": "test-mcp"
}
EOF
  
  # Mock npm
  npm() {
    return 0
  }
  export -f npm
  
  # Déployer sans opencode.json
  deploy_mcp_servers "$deploy_dir"
  configure_mcp_in_project "$deploy_dir"
  
  # Le serveur devrait être déployé même sans config
  [ -f "$deploy_dir/.opencode/servers/test-mcp/dist/index.js" ]
}

# ── Injection credentials ──────────────────────────────────────────────────

@test "configure_mcp_in_project : injecte credentials globaux depuis services-env.json" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir/.opencode/servers/figma-mcp/dist"

  cat > "$deploy_dir/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json"
}
EOF

  # Configurer credentials globaux dans services-env.json
  printf '{"env":{"FIGMA_PERSONAL_ACCESS_TOKEN":"figd_global","FIGMA_TEAM_ID":"12345"}}\n' \
    > "$OPENCODE_GLOBAL_CONFIG"

  which jq >/dev/null 2>&1 || skip "jq non disponible"

  configure_mcp_in_project "$deploy_dir"

  # Les credentials globaux doivent être injectés dans environment
  assert_json_field "$deploy_dir/opencode.json" \
    '.mcp["figma-mcp"].environment.FIGMA_PERSONAL_ACCESS_TOKEN' "figd_global"
  assert_json_field "$deploy_dir/opencode.json" \
    '.mcp["figma-mcp"].environment.FIGMA_TEAM_ID' "12345"
}

@test "configure_mcp_in_project : project env écrase le global" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir/.opencode/servers/figma-mcp/dist"

  # opencode.json avec override projet existant
  cat > "$deploy_dir/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "figma-mcp": {
      "type": "local",
      "command": ["node", ".opencode/servers/figma-mcp/dist/index.js"],
      "environment": {
        "FIGMA_PERSONAL_ACCESS_TOKEN": "figd_project_override",
        "FIGMA_TEAM_ID": "99999"
      }
    }
  }
}
EOF

  # Credentials globaux différents
  printf '{"env":{"FIGMA_PERSONAL_ACCESS_TOKEN":"figd_global","FIGMA_TEAM_ID":"00000"}}\n' \
    > "$OPENCODE_GLOBAL_CONFIG"

  which jq >/dev/null 2>&1 || skip "jq non disponible"

  configure_mcp_in_project "$deploy_dir"

  # Le token projet doit primer sur le global
  assert_json_field "$deploy_dir/opencode.json" \
    '.mcp["figma-mcp"].environment.FIGMA_PERSONAL_ACCESS_TOKEN' "figd_project_override"
  assert_json_field "$deploy_dir/opencode.json" \
    '.mcp["figma-mcp"].environment.FIGMA_TEAM_ID' "99999"
}

@test "configure_mcp_in_project : environment vide si services-env.json absent" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir/.opencode/servers/figma-mcp/dist"

  cat > "$deploy_dir/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json"
}
EOF

  # Pas de services-env.json
  rm -f "$OPENCODE_GLOBAL_CONFIG"

  which jq >/dev/null 2>&1 || skip "jq non disponible"

  configure_mcp_in_project "$deploy_dir"

  # La config MCP doit quand même être créée, avec environment vide
  run jq -r '.mcp["figma-mcp"].type' "$deploy_dir/opencode.json"
  [ "$output" = "local" ]
  run jq -r '.mcp["figma-mcp"].environment | length' "$deploy_dir/opencode.json"
  [ "$output" = "0" ]
}

# ── gitlab-mcp ────────────────────────────────────────────────────────────────

@test "configure_mcp_in_project : configure gitlab-mcp" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir/.opencode/servers/gitlab-mcp/dist"

  cat > "$deploy_dir/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json"
}
EOF

  which jq >/dev/null 2>&1 || skip "jq non disponible"

  configure_mcp_in_project "$deploy_dir"

  # La config MCP gitlab-mcp doit être créée
  assert_json_field "$deploy_dir/opencode.json" \
    '.mcp["gitlab-mcp"].type' "local"
  run jq -r '.mcp["gitlab-mcp"].command[1]' "$deploy_dir/opencode.json"
  [ "$output" = ".opencode/servers/gitlab-mcp/dist/index.js" ]
}

@test "configure_mcp_in_project : injecte credentials globaux gitlab depuis services-env.json" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir/.opencode/servers/gitlab-mcp/dist"

  cat > "$deploy_dir/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json"
}
EOF

  # Configurer credentials globaux dans services-env.json
  printf '{"env":{"GITLAB_PERSONAL_ACCESS_TOKEN":"glpat-global","GITLAB_BASE_URL":"https://gitlab.example.com"}}\n' \
    > "$OPENCODE_GLOBAL_CONFIG"

  which jq >/dev/null 2>&1 || skip "jq non disponible"

  configure_mcp_in_project "$deploy_dir"

  # Les credentials globaux doivent être injectés dans environment
  assert_json_field "$deploy_dir/opencode.json" \
    '.mcp["gitlab-mcp"].environment.GITLAB_PERSONAL_ACCESS_TOKEN' "glpat-global"
  assert_json_field "$deploy_dir/opencode.json" \
    '.mcp["gitlab-mcp"].environment.GITLAB_BASE_URL' "https://gitlab.example.com"
}

@test "configure_mcp_in_project : project env gitlab écrase le global" {
  local deploy_dir="$TEST_DIR/project"
  mkdir -p "$deploy_dir/.opencode/servers/gitlab-mcp/dist"

  # opencode.json avec override projet existant
  cat > "$deploy_dir/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "gitlab-mcp": {
      "type": "local",
      "command": ["node", ".opencode/servers/gitlab-mcp/dist/index.js"],
      "environment": {
        "GITLAB_PERSONAL_ACCESS_TOKEN": "glpat-project-override",
        "GITLAB_BASE_URL": "https://gitlab.project.com"
      }
    }
  }
}
EOF

  # Credentials globaux différents
  printf '{"env":{"GITLAB_PERSONAL_ACCESS_TOKEN":"glpat-global","GITLAB_BASE_URL":"https://gitlab.global.com"}}\n' \
    > "$OPENCODE_GLOBAL_CONFIG"

  which jq >/dev/null 2>&1 || skip "jq non disponible"

  configure_mcp_in_project "$deploy_dir"

  # Le token projet doit primer sur le global
  assert_json_field "$deploy_dir/opencode.json" \
    '.mcp["gitlab-mcp"].environment.GITLAB_PERSONAL_ACCESS_TOKEN' "glpat-project-override"
  assert_json_field "$deploy_dir/opencode.json" \
    '.mcp["gitlab-mcp"].environment.GITLAB_BASE_URL' "https://gitlab.project.com"
}

# ── Filtrage MCP par projet (PROJECT_ID) ────────────────────────────────────

@test "deploy_mcp_servers : ne déploie rien si MCP : none" {
  local deploy_dir="$TEST_DIR/project-filter-none"
  mkdir -p "$deploy_dir"

  # Créer un serveur buildé dans le hub
  mkdir -p "$HUB_DIR/servers/figma-mcp/dist"
  echo "console.log('figma');" > "$HUB_DIR/servers/figma-mcp/dist/index.js"
  echo '{"name":"figma-mcp","version":"1.0.0"}' > "$HUB_DIR/servers/figma-mcp/package.json"

  # Projet avec MCP : none
  cat >> "$PROJECTS_FILE" <<'EOF'

## PROJ-NOMCP
- Nom : Sans MCP
- MCP : none
EOF

  npm() { return 0; }
  export -f npm

  deploy_mcp_servers "$deploy_dir" "PROJ-NOMCP"

  [ ! -d "$deploy_dir/.opencode/servers/figma-mcp" ]
}

@test "deploy_mcp_servers : déploie seulement figma-mcp si MCP : figma-mcp" {
  local deploy_dir="$TEST_DIR/project-filter-csv"
  mkdir -p "$deploy_dir"

  # Créer 2 serveurs buildés
  for srv in figma-mcp gitlab-mcp; do
    mkdir -p "$HUB_DIR/servers/$srv/dist"
    echo "console.log('$srv');" > "$HUB_DIR/servers/$srv/dist/index.js"
    echo "{\"name\":\"$srv\",\"version\":\"1.0.0\"}" > "$HUB_DIR/servers/$srv/package.json"
  done

  cat >> "$PROJECTS_FILE" <<'EOF'

## PROJ-FIGMAONLY
- Nom : Figma Only
- MCP : figma-mcp
EOF

  npm() { return 0; }
  export -f npm

  deploy_mcp_servers "$deploy_dir" "PROJ-FIGMAONLY"

  [ -d "$deploy_dir/.opencode/servers/figma-mcp" ]
  [ ! -d "$deploy_dir/.opencode/servers/gitlab-mcp" ]
}

@test "deploy_mcp_servers : déploie tous si MCP : all" {
  local deploy_dir="$TEST_DIR/project-filter-all"
  mkdir -p "$deploy_dir"

  for srv in figma-mcp gitlab-mcp; do
    mkdir -p "$HUB_DIR/servers/$srv/dist"
    echo "console.log('$srv');" > "$HUB_DIR/servers/$srv/dist/index.js"
    echo "{\"name\":\"$srv\",\"version\":\"1.0.0\"}" > "$HUB_DIR/servers/$srv/package.json"
  done

  cat >> "$PROJECTS_FILE" <<'EOF'

## PROJ-ALLSRV
- Nom : Tous les serveurs
- MCP : all
EOF

  npm() { return 0; }
  export -f npm

  deploy_mcp_servers "$deploy_dir" "PROJ-ALLSRV"

  [ -d "$deploy_dir/.opencode/servers/figma-mcp" ]
  [ -d "$deploy_dir/.opencode/servers/gitlab-mcp" ]
}

@test "configure_mcp_in_project : ne configure rien si MCP : none" {
  local deploy_dir="$TEST_DIR/project-cfg-none"
  mkdir -p "$deploy_dir/.opencode/servers/figma-mcp/dist"

  cat > "$deploy_dir/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json"
}
EOF

  cat >> "$PROJECTS_FILE" <<'EOF'

## PROJ-CFG-NONE
- MCP : none
EOF

  which jq >/dev/null 2>&1 || skip "jq non disponible"

  configure_mcp_in_project "$deploy_dir" "PROJ-CFG-NONE"

  run jq -r '.mcp // "null"' "$deploy_dir/opencode.json"
  [ "$output" = "null" ]
}

@test "configure_mcp_in_project : configure seulement figma-mcp si MCP : figma-mcp" {
  local deploy_dir="$TEST_DIR/project-cfg-csv"
  mkdir -p "$deploy_dir/.opencode/servers/figma-mcp/dist"
  mkdir -p "$deploy_dir/.opencode/servers/gitlab-mcp/dist"

  cat > "$deploy_dir/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json"
}
EOF

  cat >> "$PROJECTS_FILE" <<'EOF'

## PROJ-CFG-CSV
- MCP : figma-mcp
EOF

  which jq >/dev/null 2>&1 || skip "jq non disponible"

  configure_mcp_in_project "$deploy_dir" "PROJ-CFG-CSV"

  run jq -r '.mcp["figma-mcp"].type' "$deploy_dir/opencode.json"
  [ "$output" = "local" ]

  run jq -r '.mcp["gitlab-mcp"] // "null"' "$deploy_dir/opencode.json"
  [ "$output" = "null" ]
}
