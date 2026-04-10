# Architecture : Adapters

Un **adapter** traduit les agents canoniques du hub vers le format natif
d'un outil IA cible (opencode, claude-code, etc.).

---

## Contrat obligatoire

Tout adapter (`scripts/adapters/<cible>.adapter.sh`) doit exporter **6 fonctions**.
Le chargement est effectué par `load_adapter()` dans `scripts/lib/adapter-manager.sh`,
qui vérifie via `declare -F` que les 6 fonctions existent après le `source`.

| Fonction | Rôle | Signature |
|----------|------|-----------|
| `adapter_validate` | Vérifie que l'outil cible est installé et accessible | `adapter_validate()` — retourne 0/1 |
| `adapter_needs_node` | Indique si Node.js est requis pour l'outil | `adapter_needs_node()` — `return 0` (oui) ou `return 1` (non) |
| `adapter_deploy` | Génère les fichiers agent dans le projet cible | `adapter_deploy deploy_dir project_id` |
| `adapter_install` | Installe l'outil cible (appelé par `oc install`) | `adapter_install()` |
| `adapter_update` | Met à jour l'outil cible (appelé par `oc update`) | `adapter_update()` |
| `adapter_start` | Lance l'outil dans le projet (appelé par `oc start`) | `adapter_start project_path prompt project_id` |

### Détail des paramètres

#### `adapter_deploy deploy_dir project_id`

- `deploy_dir` : chemin du répertoire projet où déployer (ex: `/home/user/mon-projet`)
- `project_id` : identifiant du projet dans `projects.md` (ex: `MON-PROJET`). Permet de
  lire la langue (`get_project_language`) et les clés API (`get_project_api_*`).

Responsabilités :
1. Créer l'arborescence de sortie (ex: `.opencode/agents/`, `.claude/agents/`)
2. Itérer sur les agents canoniques dans `CANONICAL_AGENTS_DIR`
3. Filtrer via `agent_supports_target` (ne déployer que les agents compatibles)
4. Appeler `build_agent_content` (de `prompt-builder.sh`) pour assembler le contenu
5. Écrire les fichiers dans le format attendu par l'outil cible

#### `adapter_start project_path prompt project_id`

- `project_path` : chemin absolu du répertoire projet
- `prompt` : prompt initial (peut être vide)
- `project_id` : identifiant du projet (pour configuration spécifique)

---

## Fonctions utilitaires disponibles

Un adapter a accès aux fonctions de `common.sh` et `prompt-builder.sh` :

| Fonction | Usage |
|----------|-------|
| `extract_frontmatter_value file key` | Lit une valeur du frontmatter YAML |
| `extract_frontmatter_list file key` | Parse une liste YAML inline → une valeur par ligne |
| `strip_frontmatter file` | Retourne le corps sans le frontmatter |
| `agent_supports_target file target` | Vérifie si un agent supporte la cible |
| `get_agent_id file` | Retourne l'`id` du frontmatter |
| `get_agent_mode file` | Retourne le `mode` du frontmatter (`primary` par défaut) |
| `get_effective_agent_mode file project_id` | Mode effectif : override projet > frontmatter > `primary` |
| `build_agent_content file [target] [lang]` | Assemble le contenu complet (header + skills + corps) |
| `get_project_language project_id` | Retourne la langue du projet (ou vide) |
| `get_project_api_provider project_id` | Retourne le provider API (anthropic, litellm, etc.) |
| `get_project_api_key project_id` | Retourne la clé API |
| `get_project_api_base_url project_id` | Retourne la base URL (ou vide) |

---

## Créer un nouvel adapter

1. Créer `scripts/adapters/<cible>.adapter.sh` avec les 6 fonctions
2. Ajouter la cible dans `config/hub.json` (`active_targets` et `default_target` si pertinent)
3. Le fichier sera chargé automatiquement par `load_adapter` — aucune modification de
   `adapter-manager.sh` n'est nécessaire
4. Tester : `oc deploy <cible>` puis vérifier les fichiers générés

### Exemple minimal

```bash
#!/bin/bash
# scripts/adapters/mon-outil.adapter.sh

adapter_validate() {
  command -v mon-outil &>/dev/null || { log_error "mon-outil non installé"; return 1; }
}

adapter_needs_node() { return 1; }

adapter_deploy() {
  local deploy_dir="${1:-$HUB_DIR}"
  local project_id="${2:-}"
  local out_dir="$deploy_dir/.mon-outil/agents"
  mkdir -p "$out_dir"

  local lang=""
  [ -n "$project_id" ] && lang=$(get_project_language "$project_id")

  while IFS= read -r f; do
    [ -f "$f" ] || continue
    agent_supports_target "$f" "mon-outil" || continue
    local agent_id; agent_id=$(get_agent_id "$f")
    local content; content=$(build_agent_content "$f" "$lang")
    printf '%s\n' "$content" > "$out_dir/${agent_id}.md"
  done < <(find "$CANONICAL_AGENTS_DIR" -name "*.md" | sort)
}

adapter_install() {
  log_info "Installation de mon-outil..."
  # ...
}

adapter_update() {
  log_info "Mise à jour de mon-outil..."
  # ...
}

adapter_start() {
  local project_path="$1" prompt="${2:-}" project_id="${3:-}"
  cd "$project_path" || exit 1
  exec mon-outil
}
```

---

## Adapters existants

| Cible | Fichier | Node requis | Spécificités |
|-------|---------|-------------|--------------|
| opencode | `opencode.adapter.sh` | Oui | Génère `opencode.json` (avec bloc `"agent":` pour les subagents) + `.opencode/agents/*.md`, injecte les clés API |
| claude-code | `claude-code.adapter.sh` | Oui | Génère `.claude/agents/*.md` — les subagents reçoivent une description préfixée pour orienter Claude vers la délégation |

### Comportement par mode selon la cible

| Mode agent | opencode | claude-code |
|-----------|----------|-------------|
| `primary` | Déployé normalement, absent du bloc `"agent":` | Déployé normalement |
| `subagent` | Déployé normalement, listé dans `"agent": { "mode": "subagent" }` | Déployé avec description préfixée `"Sous-agent interne — invoquer uniquement via un agent coordinateur…"` |
