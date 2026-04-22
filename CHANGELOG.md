# Changelog

Toutes les modifications notables de ce projet sont documentées dans ce fichier.

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/)
Versioning : [Semantic Versioning](https://semver.org/lang/fr/)

---

## [Unreleased]

---

## [1.4.0] — 2026-04-22

### Added

- Skill `developer/dev-standards-simplicity` : KISS (solution la plus directe), YAGNI
  (n'implémenter que ce qui est dans le ticket actif), pas d'abstraction prématurée
  (3 cas concrets avant d'abstraire), limites mesurables (fonction ≤ 20 lignes,
  complexité cyclomatique ≤ 10, params ≤ 4, imbrication ≤ 3 niveaux)

### Changed

- Agent `orchestrator` : permissions techniques `bash: deny`, `edit: deny`, `write: deny`
  ajoutées dans le frontmatter — l'agent agit uniquement via `task` et `question` ;
  `task` restreint à une allowlist exhaustive (`planner`, `onboarder`, `ux-designer`,
  `ui-designer`, `auditor-*`, `orchestrator-dev`, `debugger`)
- Skill `orchestrator/orchestrator-protocol` :
  - Mode C conditionné à l'absence des fichiers `ONBOARDING.md` et `CONVENTIONS.md` sur
    disque — si l'un des deux est présent, le contexte est chargé directement sans
    proposer l'onboarder
  - Questions des sous-agents contextualisées : règle ajoutée pour qu'un sous-agent
    invoqué depuis un parent inclue toujours un bloc `[Agent — Phase | Feature]` en
    tête de son champ `question`
  - CP-0 : séparation explicite entre l'affichage du tableau des tickets (dans la
    discussion) et la demande de mode de workflow (outil `question` court, sans tableau)
  - Gestion des agents non déployés : nouvelle section avec table de substitution par
    domaine (`auditor-security → developer-security`, `auditor-accessibility →
    developer-frontend`, `auditor-architecture/performance → developer-fullstack`,
    `auditor-privacy/ecodesign/observability/ux-designer/ui-designer → aucun substitut`),
    question structurée avec option de déploiement via `!oc deploy opencode <PROJECT_ID>`
    sans quitter OpenCode
  - Annonces de délégation enrichies : chaque invocation de sous-agent (planner,
    ux-designer, ui-designer, auditor-*, orchestrator-dev) annonce explicitement que
    les questions remonteront avec leur contexte
  - Mode D — router les bugs vers `debugger` sans tentative de correction autonome
- Skill `posture/tool-question` : nouvelle section "Questions posées en tant que
  sous-agent" — format obligatoire `[Nom — Phase | Feature]` en tête du champ `question`
  quand l'agent est invoqué par un parent
- Skill `orchestrator/orchestrator-workflow-modes` : extrait en source de vérité
  autonome (précédemment intégré dans `orchestrator-dev-protocol`)
- Skill `orchestrator/orchestrator-handoff-format` : extrait en source de vérité
  autonome pour le format de retour `orchestrator-dev → orchestrator`
- `agents/planning/orchestrator.md` : skills mis à jour (`orchestrator-workflow-modes`,
  `orchestrator-handoff-format` ajoutés)
- `docs/architecture/agents.fr.md` / `agents.en.md` : section `orchestrator` enrichie
  (4 modes d'entrée D/C/A/B, permissions techniques, Mode C conditionnel, gestion des
  agents manquants)
- `docs/guides/workflows.fr.md` / `workflows.en.md` : CP-0 clarifié (tableau dans la
  discussion, question courte), notes sur les questions contextualisées des sous-agents
  et sur le comportement face aux agents manquants
- `tests/test_prompt_builder.bats` : 8 nouveaux tests d'intégrité couvrant les
  permissions du frontmatter, la table de substitution, le déploiement sans quitter
  OpenCode, la condition Mode C et la règle de contexte de `tool-question`

### Fixed

- `scripts/lib/prompt-builder.sh` : suppression de la variable `task_json` inutilisée
  (avertissement ShellCheck SC2034)
- Agent `orchestrator-dev` : délégation et outil `question` corrigés — alignement
  avec le protocole `orchestrator-dev-protocol`
- `orchestrator/orchestrator-protocol` et `orchestrator-dev-protocol` : alignement
  des deux protocoles (checkpoints, format handoff, modes de workflow)

---

## [1.3.0] — 2026-04-20

### Added

- Commande `oc review [PROJECT_ID] [--branch <branche>] [--agent <agent>]` : lance
  une review IA sur un projet en invoquant l'agent `reviewer` avec le diff injecté ;
  détecte automatiquement la branche courante si `--branch` absent ; vérifie la
  présence du reviewer dans `projects.md` ; injecte `CONVENTIONS.md` si présent
- `scripts/cmd-review.sh` : implémentation complète de la commande
- `scripts/lib/prompt-builder.sh` : `build_review_bootstrap_prompt` injecte le diff
  `git diff <branche>` et l'hint `CONVENTIONS.md` conditionnel
- `oc.sh` : case `review)` ajouté dans le dispatcher
- `docs/reference/cli.md` : section `oc review` ajoutée
- Skill `orchestrator/orchestrator-workflow-modes` : source de vérité unique pour
  les 3 modes (manuel/semi-auto/auto) — injecté dans `orchestrator` et
  `orchestrator-dev` pour garantir la cohérence
- Skill `orchestrator/orchestrator-handoff-format` : source de vérité unique pour
  le format de retour `orchestrator-dev → orchestrator`

### Changed

- Agent `orchestrator` : `onboarder` ajouté dans la table des agents disponibles,
  Mode C (projet inconnu) ajouté dans le workflow avec checkpoint `[CP-onboard]`
  optionnel et sautables — exemple d'invocation Mode C ajouté
- Skill `orchestrator/orchestrator-protocol` : Mode C documenté avec condition de
  déclenchement, proposition à l'utilisateur, format du `[CP-onboard]` et règle
  "toujours optionnel et sautables"
- Agent `planner` : invocation autonome optionnelle des agents `ux-designer` et
  `ui-designer` ajoutée (PHASE 1.5) — 3 options : invoquer directement (Option A),
  laisser l'utilisateur invoquer (Option B), continuer sans (Option C)
- Agent `orchestrator-dev` : création de branche dédiée par ticket avant implémentation —
  pause obligatoire à l'étape 1b dans tous les modes
- Agents (tous) : outil `question` OpenCode activé sur tous les agents — remplacement
  des pauses textuelles par des appels structurés à l'outil `question`
- `docs(beads)` : état review et cycle de feedback clarifiés
- `docs/architecture/agents.md` : total mis à jour, `onboarder` ajouté dans la
  famille Coordinateurs, nouvelle règle "Agents de découverte"
- `docs/architecture/skills.md` : `planning/project-discovery` ajouté, matrice
  de dépendances mise à jour pour `onboarder`
- `scripts/cmd-help.sh` : refonte avec `.cmd`/`.desc` séparés dans `i18n`,
  section `beads ui` et `tracker set-sync-mode` ajoutées

### Fixed

- `scripts/lib/prompt-builder.sh` : sauts de ligne dans les templates `bd update`
  pour le planner corrigés
- `scripts/cmd-help.sh` : commandes `agent select` et `mode` manquantes ajoutées
- Agent `planner` : sauts de ligne dans les templates `bd update` corrigés
- `fix(onboarding)` : ne pas proposer l'onboarding si `ONBOARDING.md` existe déjà
- `fix(release)` : bumper `hub.json.example` (tracké) au lieu de `hub.json` (ignoré)
- Agents `orchestrator`/`orchestrator-dev` : synchronisation de la permission
  `question` et du skill `tool-question`
- CI : avertissements ShellCheck corrigés dans `cmd-board` et `common`

---

## [1.2.0] — 2026-04-15

### Added

- Support natif AWS Bedrock (`amazon-bedrock`) : détection automatique du provider
  dans `opencode.adapter.sh`, sync `opencode.json` avec region et token
  `AWS_BEARER_TOKEN_BEDROCK` ; différencié du mode litellm
- Support région AWS pour le provider `amazon-bedrock` dans `providers.json`
- `feat(beads)` : ajout de `.beads/` au `.git/info/exclude` à l'init
- `feat(i18n)` : clés `beads.gitignore_added` et `beads.gitignore_exists` ajoutées
- `feat(beads-ui)` : intégration de `bdui` dans `oc install`, `oc update` et la
  documentation
- Import automatique des labels tracker (GitLab / Jira) à l'init Beads

### Changed

- `feat(deploy)` : utilisation de `.git/info/exclude` au lieu de `.gitignore` dans
  les projets cibles — évite de polluer le `.gitignore` versionné des projets
- `chore(config)` : `hub.json` et `opencode.json` retirés du tracking git, ajoutés
  à `.gitignore`
- `docs` : section prérequis retirée du README (EN + FR)

### Fixed

- `fix(beads)` : remplacement de `bd label add` par `bd label create` dans
  `cmd-init.sh` — alignement avec l'API Beads actuelle
- `fix(tests)` : stabilisation des tests BATS pour CI sans `hub.json`
- `test` : assertions BATS corrigées (`bd label add` → `bd label create`)

---

## [1.1.0] — 2026-04-13

### Added

- `feat(beads)` : champ `Sync mode` dans `projects.md` et commande
  `oc beads tracker set-sync-mode` pour configurer le mode de synchronisation
  du tracker
- Commande `oc init` : proposition d'ajout de `opencode.json` et `.opencode/` au
  `.gitignore` du projet à l'étape 5

### Fixed

- `fix(init)` : suppression des déclarations `local` invalides hors scope de fonction
- `fix(help)` : commandes `agent select` et `mode` manquantes ajoutées dans l'aide

---

## [1.0.0] — 2026-03-29

### Added

- Commande `oc upgrade` : met à jour les sources du hub via `git pull` (main) ou
  `git checkout <tag>` (`oc upgrade v1.1.0`). Propose `oc sync` après mise à jour réussie.
  Support du one-liner `VERSION=vX.Y.Z` dans `install.sh` pour installer une version épinglée.
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

## [0.1.0] — 2026-03-26

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
