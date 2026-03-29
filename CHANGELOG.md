# Changelog

Toutes les modifications notables de ce projet sont documentées dans ce fichier.

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/)
Versioning : [Semantic Versioning](https://semver.org/lang/fr/)

---

## [Unreleased]

### Added

- Skill `developer/dev-standards-security` : pratiques de sécurité préventives
  (secrets/config, validation des inputs, injections SQL/shell/LDAP, auth/autorisation,
  logs sans données sensibles, audit des dépendances) — injecté dans tous les developer-* et reviewer
- Adaptation linguistique des agents (ADR-005) : champ optionnel `Langue` dans `projects.md`
  — si présent, une instruction de langue est injectée en tête de chaque agent déployé via
  `build_agent_content` ; comportement par défaut (champ absent) inchangé — rétrocompatible
- Mode de workflow configurable pour l'orchestrateur (ADR-006) : trois modes disponibles au
  démarrage de chaque feature — `manuel` (défaut, comportement existant inchangé), `semi-auto`
  (CP-1 et CP-3 automatiques, QA et review restent manuels), `auto` (CP-1/CP-3 automatiques,
  CP-QA fixé au démarrage) — CP-2 (merge ou corriger ?) reste une pause absolue dans tous
  les modes — rétrocompatible

### Changed

- Tous les developer-* et reviewer : `dev-standards-security` ajouté après `dev-standards-universal`
  dans le frontmatter `skills`
- `scripts/lib/prompt-builder.sh` : `build_agent_content` accepte un 3e paramètre `lang` (optionnel)
- `scripts/common.sh` : nouvelle fonction `get_project_language` (lecture du champ `Langue` dans `projects.md`)
- `scripts/adapters/opencode.adapter.sh`, `claude-code.adapter.sh`, `vscode.adapter.sh` :
  lecture de la langue via `get_project_language` et passage à `build_agent_content`
- `projects/projects.example.md` et `docs/reference/config.md` : champ `Langue` documenté
- `docs/architecture/adr/005-agent-language-adaptation.md` : statut Proposé → Accepté,
  sections Décision, Implémentation et Options rejetées ajoutées
- `docs/architecture/skills.md` et `agents.md` : mis à jour avec `dev-standards-security`

---

## [2.0.0] — 2026-03-29

### Added

- Agent `documentarian` (famille Documentation) avec 5 skills spécialisés :
  `doc-protocol`, `doc-standards`, `doc-adr`, `doc-api`, `doc-changelog`
- Skill `planning/planner.md` : Phase 0 (exploration adaptative de la codebase
  et des tickets existants, résumé de contexte), Phase 1 (questions contextualisées,
  priorités déduites et justifiées), Phase 2 (plan hiérarchique epics → tickets,
  règle >5 tickets pour création epics dans Beads), Phase 3 (`--parent`, `--deps`,
  `--estimate`), Phase 4 (`bd children`), section gestion des aléas
- `CHANGELOG.md` et `CONTRIBUTING.md` à la racine du dépôt

### Changed

- Restructuration de `agents/` en sous-dossiers par famille :
  `auditor/`, `developer/`, `documentation/`, `planning/`, `quality/`
- Migration `skills/planner.md` → `skills/planning/planner.md` — cohérence
  avec la convention de sous-dossiers par domaine
- Agent `planner` : frontmatter enrichi (skill `developer/dev-beads` ajouté),
  corps restructuré avec ce que l'agent lit, ce qu'il produit, tableau des aléas
- CI `validate-agents` : glob `agents/*.md` → `find agents/ -name "*.md"`
  pour couvrir la structure en sous-dossiers (le job était en faux positif permanent)

### Fixed

- `scripts/cmd-agent.sh` : `_find_agent_file` réécrit avec process substitution
  `< <(find ...)` — le `return 0` dans un pipe ne sortait pas de la fonction
- `scripts/cmd-skills.sh` : message d'aide corrigé (`agents/*.md` →
  `agents/<famille>/<id>.md`)
- `docs/guides/contributing.md` : chemins `agents/auditor.md`,
  `agents/developer-frontend.md` et `scripts/adapter-manager.sh` obsolètes corrigés
- `docs/architecture/skills.md` : matrice ASCII `developer-fullstack` complétée
  avec `dev-standards-frontend-a11y` et `dev-standards-vuejs`

---

## [1.0.0] — 2026-03-26

### Added

- Hub central multi-cible : OpenCode, Claude Code, VS Code / Copilot
- CLI `oc.sh` avec 13 commandes : `init`, `deploy`, `start`, `list`, `remove`,
  `agent`, `skills`, `beads`, `sync`, `update`, `install`, `version`, `help`
- 19 agents initiaux organisés en 5 familles :
  - Coordinateurs : `orchestrator`, `auditor`
  - Développeurs : `developer-frontend`, `developer-backend`, `developer-fullstack`,
    `developer-data`, `developer-devops`, `developer-mobile`, `developer-api`
  - Qualité : `reviewer`, `qa-engineer`, `debugger`
  - Audit : `auditor-security`, `auditor-performance`, `auditor-accessibility`,
    `auditor-ecodesign`, `auditor-architecture`, `auditor-privacy`
  - Planification : `planner`
- 27 skills organisés par domaine (`developer/`, `auditor/`, `orchestrator/`,
  `qa/`, `debugger/`, `reviewer/`)
- 3 adapters : `opencode.adapter.sh`, `claude-code.adapter.sh`, `vscode.adapter.sh`
- Intégration Beads (`bd`) pour la gestion des tickets : `cmd-beads.sh`,
  workflow `bd claim → implémenter → bd close` dans tous les agents developers
- Commande `oc agent` : création interactive, édition, liste, info
- Commande `oc skills` : liste, ajout de sources externes, `used-by`
- Sélecteur de skills interactif avec navigation clavier (flèches + espace)
- Staleness detection : `oc deploy --check` pour détecter les agents obsolètes
- CI GitHub Actions : ShellCheck, validation frontmatter agents, staleness check
- Documentation complète : 5 ADR, guides (getting-started, workflows, contributing),
  référence CLI et config, architecture overview avec diagrammes Mermaid
- Support multi-projets via `projects.md` et `oc init` / `oc start`
- Config `hub.json` : targets actives, modèle IA, skills globaux VS Code
