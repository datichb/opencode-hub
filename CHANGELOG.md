# Changelog

Toutes les modifications notables de ce projet sont documentées dans ce fichier.

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/)
Versioning : [Semantic Versioning](https://semver.org/lang/fr/)

---

## [Unreleased]

### Added

- Skill `posture/expert-posture` : posture transverse injectable dans les agents experts —
  exploration systématique des artefacts avant de répondre (annonce de ce qui a été consulté,
  identification des zones d'incertitude), recommandation contraire argumentée au format ⚠️
  (problème / alternative / pourquoi / trade-offs, formulation à la première personne),
  pause de confirmation 🛑 avant toute action irréversible ou structurellement impactante —
  injecté dans 11 agents : `auditor`, `auditor-security`, `auditor-performance`,
  `auditor-accessibility`, `auditor-ecodesign`, `auditor-architecture`, `auditor-privacy`,
  `auditor-observability`, `ux-designer`, `ui-designer`, `planner`

- Skill `developer/dev-standards-security` : pratiques de sécurité préventives
  (secrets/config, validation des inputs, injections SQL/shell/LDAP, auth/autorisation,
  logs sans données sensibles, audit des dépendances) — injecté dans tous les developer-* et reviewer
- Adaptation linguistique des agents (ADR-005) : champ optionnel `Langue` dans `projects.md`
  — si présent, une instruction de langue est injectée en tête de chaque agent déployé via
  `build_agent_content` ; comportement par défaut (champ absent) inchangé — rétrocompatible
- Mode de workflow configurable pour l'orchestrateur dev (ADR-006) : trois modes disponibles au
  démarrage de chaque session `orchestrator-dev` — `manuel` (défaut, comportement existant inchangé),
  `semi-auto` (CP-1 et CP-3 automatiques, QA et review restent manuels), `auto` (CP-1/CP-3
  automatiques, CP-QA fixé au démarrage) — CP-2 (merge ou corriger ?) reste une pause absolue
  dans tous les modes — modes applicables à `orchestrator-dev` uniquement — rétrocompatible
- Nouvelle famille `design/` avec 2 agents :
  - Agent `ux-designer` : analyse des flows utilisateur, identification des frictions, user flows
    textuels, spécifications UX avec critères d'acceptance, audit UX (heuristiques Nielsen)
  - Agent `ui-designer` : fondations design system (tokens), spécification de composants
    (variants, états, do/don't), guidelines visuelles, direction artistique multi-options
- Skill `designer/ux-protocol` : heuristiques Nielsen, grille des 5 questions UX, format user flow,
  format spec UX, protocole d'audit friction
- Skill `designer/ui-protocol` : tokens de design, format spec composant, règles de cohérence
  visuelle, protocole d'audit d'incohérences, échelle modulaire typographique
- Agent `developer-platform` (famille developer/) : infrastructure as code (Terraform, Pulumi),
  orchestration Kubernetes, Helm charts, GitOps (ArgoCD, Flux), gestion des secrets à l'échelle
  (Vault, External Secrets Operator) — distinct de `developer-devops`
- Skill `developer/dev-standards-platform` : Terraform (modules versionnés, state remote,
  workspaces), K8s (Kustomize, RBAC minimal, probes), Helm (charts SemVer, ESO uniquement),
  GitOps (sync auto staging / manuel prod), validation (`terraform plan`, `helm diff`)
- Agent `auditor-observability` (famille auditor/) : méthode RED, logs structurés, traces
  distribuées (OpenTelemetry), SLOs/error budget, alerting (actionnable, runbooks), dashboards,
  grille des 5 questions d'observabilité
- Skill `auditor/audit-observability` : méthode RED complète, grille des 5 questions, format
  de rapport par pilier (métriques → logs → traces → SLOs → alerting → dashboards)
- Agent `orchestrator-dev` (famille planning/) : tech lead IA d'implémentation — pilote le
  workflow Beads ticket par ticket, route vers 8 agents developer-*, supervise QA optionnel
  et review, 3 modes (manuel/semi-auto/auto), invocable standalone ou depuis l'orchestrator
- Skill `orchestrator/orchestrator-dev-protocol` : workflow Beads d'implémentation, matrice
  de routing developer-* (8 signaux → 8 agents), format checkpoints CP-1/CP-QA/CP-2/CP-3,
  3 modes de workflow, format compte rendu d'étape et récap global

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
- Agent `orchestrator` refondu en chef de projet feature : délègue conception (ux-designer,
  ui-designer), audits (auditor-*) et implémentation (orchestrator-dev) — ne route plus
  directement vers les developer-*
- Skill `orchestrator/orchestrator-protocol` refondu : workflow feature complet, matrice de
  routing 3 familles (design/auditor/dev via orchestrator-dev), checkpoints CP-0/CP-spec/
  CP-audit/CP-feature
- `agents/auditor/auditor.md` : ajout de `auditor-observability` dans la table des sous-agents,
  tableau de synthèse multi-domaines et exemples d'invocation
- `docs/architecture/agents.md` : mise à jour du total (25 agents, 7 familles), ajout famille
  design/, `orchestrator-dev`, `developer-platform`, `auditor-observability`, refonte description
  `orchestrator`
- `docs/architecture/skills.md` : ajout domaine `designer/`, `dev-standards-platform`,
  `audit-observability`, `orchestrator-dev-protocol` dans le domaine orchestrator/ ; matrice
  de dépendances complétée
- `docs/architecture/adr/006-orchestrator-configurable-mode.md` : titre et texte clarifiés —
  les modes s'appliquent à `orchestrator-dev` uniquement, pas à l'`orchestrator` feature

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
