#!/usr/bin/env bats
# Tests pour scripts/adapters/vscode.adapter.sh
# Fonctions testées : adapter_deploy (génération copilot-instructions.md + prompts/*.prompt.md)
# Stratégie : sourcer common.sh + prompt-builder.sh + vscode.adapter.sh
#             avec un agent de test minimal dans CANONICAL_AGENTS_DIR
#             et un skill global de test dans SKILLS_DIR

setup() {
  TEST_DIR="$(mktemp -d)"
  DEPLOY_DIR="$(mktemp -d)"
  AGENTS_DIR="$(mktemp -d)"
  SKILLS_TMP_DIR="$(mktemp -d)"

  # Fixer HUB_DIR avant le source
  HUB_DIR="$BATS_TEST_DIRNAME/.."

  source "$BATS_TEST_DIRNAME/../scripts/common.sh"

  # Surcharger les chemins après le source
  PROJECTS_FILE="$TEST_DIR/projects.md"
  API_KEYS_FILE="$TEST_DIR/api-keys.local.md"
  CANONICAL_AGENTS_DIR="$AGENTS_DIR"
  SKILLS_DIR="$SKILLS_TMP_DIR"

  # Créer un skill global de test
  mkdir -p "$SKILLS_TMP_DIR/developer"
  cat > "$SKILLS_TMP_DIR/developer/dev-standards-universal.md" <<'SKILLEOF'
---
id: dev-standards-universal
label: Standards universels
---

# Standards universels

Respecter les conventions de code du projet.
SKILLEOF

  # Créer un agent supportant vscode
  mkdir -p "$AGENTS_DIR/test"
  cat > "$AGENTS_DIR/test/test-agent.md" <<'AGENTEOF'
---
id: test-agent
label: TestAgent
description: Un agent de test pour bats
targets: [vscode]
skills: []
---

# Agent de test

Ceci est le corps de l'agent de test.
AGENTEOF

  # Créer un agent qui ne supporte PAS vscode (seulement opencode)
  cat > "$AGENTS_DIR/test/opencode-only.md" <<'AGENTEOF'
---
id: opencode-only
label: OpencodeOnly
description: Agent opencode uniquement
targets: [opencode]
skills: []
---

# Opencode Only
AGENTEOF

  # Créer un agent supportant vscode ET claude-code
  cat > "$AGENTS_DIR/test/multi-target.md" <<'AGENTEOF'
---
id: multi-target
label: MultiTarget
description: Agent multi-cible avec apostrophe d'test
targets: [vscode, claude-code]
skills: []
---

# Multi Target Agent

Contenu multi-cible.
AGENTEOF

  source "$BATS_TEST_DIRNAME/../scripts/lib/prompt-builder.sh"
  source "$BATS_TEST_DIRNAME/../scripts/adapters/vscode.adapter.sh"

  # Mocks
  log_info()    { true; }
  log_success() { true; }
  log_warn()    { true; }
  log_error()   { true; }
  get_project_language() { echo ""; }

  # Mock _get_vscode_global_skills pour utiliser notre skill de test
  _get_vscode_global_skills() {
    echo "developer/dev-standards-universal"
  }
}

teardown() {
  rm -rf "$TEST_DIR" "$DEPLOY_DIR" "$AGENTS_DIR" "$SKILLS_TMP_DIR"
}

# ── adapter_deploy : structure des dossiers ──────────────────────────────────

@test "vscode adapter_deploy : crée le dossier .github/" {
  adapter_deploy "$DEPLOY_DIR" ""
  [ -d "$DEPLOY_DIR/.github" ]
}

@test "vscode adapter_deploy : crée le dossier .vscode/prompts/" {
  adapter_deploy "$DEPLOY_DIR" ""
  [ -d "$DEPLOY_DIR/.vscode/prompts" ]
}

# ── copilot-instructions.md ──────────────────────────────────────────────────

@test "vscode adapter_deploy : génère copilot-instructions.md" {
  adapter_deploy "$DEPLOY_DIR" ""
  [ -f "$DEPLOY_DIR/.github/copilot-instructions.md" ]
}

@test "vscode adapter_deploy : copilot-instructions.md contient le header généré" {
  adapter_deploy "$DEPLOY_DIR" ""
  # build_generated_header produit un commentaire HTML
  grep -q "<!-- " "$DEPLOY_DIR/.github/copilot-instructions.md"
}

@test "vscode adapter_deploy : copilot-instructions.md contient le contenu du skill global" {
  adapter_deploy "$DEPLOY_DIR" ""
  grep -q "Respecter les conventions de code" "$DEPLOY_DIR/.github/copilot-instructions.md"
}

@test "vscode adapter_deploy : copilot-instructions.md ne contient pas le frontmatter du skill" {
  adapter_deploy "$DEPLOY_DIR" ""
  ! grep -q "^id: dev-standards" "$DEPLOY_DIR/.github/copilot-instructions.md"
}

# ── Fichiers prompt par agent ────────────────────────────────────────────────

@test "vscode adapter_deploy : génère le prompt pour un agent supportant vscode" {
  adapter_deploy "$DEPLOY_DIR" ""
  [ -f "$DEPLOY_DIR/.vscode/prompts/test-agent.prompt.md" ]
}

@test "vscode adapter_deploy : ne génère pas de prompt pour un agent ne supportant pas vscode" {
  adapter_deploy "$DEPLOY_DIR" ""
  [ ! -f "$DEPLOY_DIR/.vscode/prompts/opencode-only.prompt.md" ]
}

@test "vscode adapter_deploy : génère le prompt pour un agent multi-cible incluant vscode" {
  adapter_deploy "$DEPLOY_DIR" ""
  [ -f "$DEPLOY_DIR/.vscode/prompts/multi-target.prompt.md" ]
}

# ── Frontmatter du prompt ────────────────────────────────────────────────────

@test "vscode adapter_deploy : prompt contient mode: agent dans le frontmatter" {
  adapter_deploy "$DEPLOY_DIR" ""
  grep -q "^mode: agent" "$DEPLOY_DIR/.vscode/prompts/test-agent.prompt.md"
}

@test "vscode adapter_deploy : prompt contient la description dans le frontmatter" {
  adapter_deploy "$DEPLOY_DIR" ""
  grep -q "description:.*Un agent de test pour bats" "$DEPLOY_DIR/.vscode/prompts/test-agent.prompt.md"
}

@test "vscode adapter_deploy : prompt contient le corps de l'agent" {
  adapter_deploy "$DEPLOY_DIR" ""
  grep -q "Ceci est le corps" "$DEPLOY_DIR/.vscode/prompts/test-agent.prompt.md"
}

@test "vscode adapter_deploy : apostrophe dans description est échappée" {
  adapter_deploy "$DEPLOY_DIR" ""
  # Le substitution bash ${//\'/\'\'} produit \'\' (backslash-escaped)
  # Vérifier que l'apostrophe brute n'apparaît pas non-échappée dans la valeur YAML
  local desc_line
  desc_line=$(grep "^description:" "$DEPLOY_DIR/.vscode/prompts/multi-target.prompt.md")
  # La ligne doit contenir la description (pas vide)
  [[ "$desc_line" == *"multi-cible"* ]]
  # L'apostrophe originale doit être transformée (pas d'apostrophe nue entre les quotes externes)
  [[ "$desc_line" == *"d\\'\\'"* ]]
}

# ── Langue du projet ─────────────────────────────────────────────────────────

@test "vscode adapter_deploy : avec langue, le contenu inclut l'instruction de langue" {
  get_project_language() { echo "english"; }
  adapter_deploy "$DEPLOY_DIR" "PROJ-EN"
  grep -qi "english" "$DEPLOY_DIR/.vscode/prompts/test-agent.prompt.md"
}
