# Changelog

Toutes les modifications notables de ce projet sont documentées dans ce fichier.

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/)
Versioning : [Semantic Versioning](https://semver.org/lang/fr/)

---

## [Unreleased]

### Added

- Désactivation des agents natifs OpenCode (`build`, `plan`, `general`, `explore`) :
  - `config/hub.json` : nouveau champ `opencode.disabled_native_agents` (tableau JSON) —
    défaut : `["build", "plan"]`
  - `projects/projects.md` : nouveau champ optionnel `- Disable agents :` (CSV) — surcharge
    la valeur hub pour un projet donné ; piloté depuis `oc init` via sélecteur interactif
  - `scripts/adapters/opencode.adapter.sh` : injection automatique de `"disable": true` dans
    le bloc `"agent":` de `opencode.json` pour chaque agent désactivé (résolution : projet > hub)
  - `scripts/common.sh` : fonctions `get_hub_disabled_native_agents`, `get_project_disabled_native_agents`, `_set_project_disabled_native_agents`
  - `scripts/lib/agent-picker.sh` : nouveau picker `_pick_native_agents` + renderer `_render_native_agents_page`
  - `scripts/cmd-init.sh` : nouvelle question après le sélecteur de cibles — affiche les agents désactivés par le hub, propose de surcharger par projet si opencode est une cible active
  - `projects/projects.example.md` : champs `Agents`, `Targets` et `Disable agents` documentés dans le bloc FORMAT
  - `docs/reference/config.md` : `opencode.disabled_native_agents` documenté, exemple `opencode.json` mis à jour, champ `Disable agents` dans la référence `projects.md`

- Commande `oc audit [PROJECT_ID] [--type <type>]` : lance un audit IA sur un projet
  en invoquant l'agent `auditor` (audit global) ou `auditor-<type>` pour un domaine précis
  (`security`, `accessibility`, `architecture`, `ecodesign`, `observability`, `performance`,
  `privacy`) — vérifie la présence des agents requis dans `projects.md` et propose l'ajout +
  redéploiement si manquants ; affiche un menu des agents audit physiquement déployés si l'ajout
  est refusé ; bloque explicitement pour la cible `vscode` (pas de support `--agent`) ;
  propose `oc deploy` si le dossier agents est absent ou les fichiers manquants
- `scripts/cmd-audit.sh` : implémentation complète de la commande
- `scripts/lib/prompt-builder.sh` : nouvelle fonction `build_audit_bootstrap_prompt(project_path, project_id, audit_type)` —
  prompt structuré avec périmètre conditionnel selon `--type`
- `oc.sh` : case `audit)` ajouté dans le dispatcher
- `docs/reference/cli.md` : section `oc audit` ajoutée

### Changed

- `oc start` : nouveau flag `--agent <nom>` — passe l'agent directement à l'outil au lancement ;
  `--onboard` force l'agent `onboarder` ; `--dev` force l'agent `orchestrator-dev`
- `scripts/adapters/opencode.adapter.sh`, `claude-code.adapter.sh` : `adapter_start` accepte
  le 4e argument `agent_name` et le passe via `--agent` à la CLI cible
- Agent `onboarder` : ne se présente plus avec "Tu es l'Onboarder" (rôle chargé via `--agent`) ;
  génère `ONBOARDING.md` à la racine du projet en fin d'exploration ; ajoute `ONBOARDING.md`
  au `.gitignore` du projet
- `scripts/lib/prompt-builder.sh` : `build_onboard_bootstrap_prompt` ne contient plus
  l'auto-présentation de rôle
- `scripts/cmd-init.sh`, `scripts/cmd-beads.sh` : remote git vérifié sur `origin` OU `upstream`
  (pas seulement `upstream`) ; confirmations dans le fil du wizard ; récap final enrichi

 — sous-commandes
  `set` (flux interactif avec saisie masquée de la clé), `get`, `list`, `unset` ; stockage
  local dans `projects/api-keys.local.md` (non versionné) au format INI-like ; providers
  supportés : `anthropic` (clé directe) et `litellm` / compatible OpenAI (avec `base_url`)
- `scripts/cmd-config.sh` : implémentation complète de la commande — parser INI-like,
  affichage masqué des clés (8 premiers caractères + `***`), proposition automatique de
  re-déploiement après `set`
- `scripts/common.sh` : parser INI-like (`_api_keys_get`), fonctions `get_project_api_model`,
  `get_project_api_provider`, `get_project_api_key`, `get_project_api_base_url`,
  `api_keys_entry_exists` ; constante `API_KEYS_FILE`

### Changed

- `scripts/adapters/opencode.adapter.sh` : `_get_opencode_model()` lit désormais
  `api-keys.local.md` en priorité (niveau 1 avant `$OPENCODE_MODEL` et `hub.json`) ;
  `adapter_deploy()` génère le bloc `provider` complet dans `opencode.json` si une clé est
  configurée pour le projet, régénère le fichier à chaque déploiement dans ce cas,
  applique `chmod 600` et ajoute `opencode.json` au `.gitignore` du projet cible
- `scripts/adapters/claude-code.adapter.sh` : `adapter_start()` injecte `ANTHROPIC_API_KEY`
  depuis `api-keys.local.md` si une clé est configurée pour le projet
- `oc.sh` : ajout du case `config)` dans le dispatcher
- `scripts/cmd-help.sh` : section "Configuration API" avec les 4 sous-commandes
- `docs/reference/config.md` : sections `projects/api-keys.local.md`, `oc config` et
  `opencode.json` mises à jour (formats avec/sans clé, règle `.gitignore`, priorité modèle)
- `.gitignore` : ajout de `projects/api-keys.local.md`

- Agent `onboarder` (famille planning/) : découverte d'un projet existant en lecture
  seule — détecte la stack, explore adaptativement les fichiers structurants selon le
  profil (Vue, React, Node.js, Python, API, Data/ML, DevOps/Platform, Mobile), lit les
  tickets Beads et ADRs existants, produit un rapport de contexte structuré (stack,
  architecture, patterns, points d'attention 🔴/🟠/🟡, zones d'ombre, questions de
  clarification) et une carte des agents recommandés à double entrée (prioritaires par
  risques détectés + recommandés par stack + optionnels avec invocations suggérées) —
  invocable directement, depuis `oc start` (suggestion affichée) ou depuis l'orchestrator
  (Mode C — pré-phase sur projet inconnu)
- Skill `planning/project-discovery` : protocole complet d'exploration adaptative —
  détection de stack (manifestes, CI, infra), tableaux de fichiers structurants par profil
  (8 profils couverts), format du rapport de contexte imposé, matrice de recommandation
  des agents (13 signaux → agents prioritaires, 14 stacks → agents recommandés, 4 cas →
  agents optionnels), règles de conduite (honnêteté sur les zones d'ombre, citations
  concrètes pour les 🔴/🟠, invocations suggérées jamais exécutées), protocole de mise
  à jour `projects.md` avec confirmation explicite
- `docs/guides/onboarding.md` : guide utilisateur complet — quand invoquer l'onboarder
  (4 situations), session complète annotée (invocation → exploration → rapport → carte
  agents), interprétation du rapport (niveaux 🔴/🟠/🟡, zones d'ombre, carte agents),
  intégration dans le workflow orchestrator (Mode C avec exemple), cas d'usage avancés
  (onboarder + planner en séquence, onboarder + auditor en séquence, re-onboarding)

### Changed

- Agent `orchestrator` : `onboarder` ajouté dans la table des agents disponibles,
  Mode C (projet inconnu) ajouté dans le workflow avec checkpoint `[CP-onboard]`
  optionnel et sautables — exemple d'invocation Mode C ajouté
- Skill `orchestrator/orchestrator-protocol` : Mode C documenté avec condition de
  déclenchement, proposition à l'utilisateur, format du `[CP-onboard]` et règle
  "toujours optionnel et sautables"
- `scripts/cmd-start.sh` : suggestion d'invocation de l'onboarder affichée au
  démarrage quand les agents sont déployés dans le projet
- `docs/architecture/agents.md` : total mis à jour (27 agents), `onboarder` ajouté
  dans la famille Coordinateurs, nouvelle règle "Agents de découverte" en bas du fichier
- `docs/architecture/skills.md` : `planning/project-discovery` ajouté dans le domaine
  planning/, matrice de dépendances mise à jour pour `onboarder`

- Agent `developer-security` (famille developer/) : hardening applicatif post-audit —
  implémente CORS restrictif, headers HTTP de sécurité (CSP, HSTS, X-Frame-Options),
  hashing des mots de passe (bcrypt, argon2id), gestion sécurisée des tokens JWT
  (rotation, révocation), sessions (httpOnly, secure, sameSite), rate limiting sur les
  endpoints sensibles, chiffrement AES-256-GCM — intervient après `auditor-security`
  dans l'ordre de criticité 🔴 → 🟠 → 🟡
- Skill `developer/dev-standards-security-hardening` : patterns concrets de hardening
  applicatif — configuration CORS (origines explicites, méthodes autorisées, headers
  exposés), headers HTTP (CSP, HSTS, X-Frame-Options, X-Content-Type-Options,
  Permissions-Policy), bcrypt/argon2id (coût, upgrade legacy), JWT (algorithme HS256
  interdit, rotation, révocation via liste de révocation), sessions (régénération après
  auth, expiration), rate limiting (throttling par IP/user/endpoint), chiffrement
  AES-256-GCM (IV aléatoire, séparation clé de chiffrement / clé d'authentification)
- Skill `developer/dev-standards-api` : standards de conception et d'implémentation
  d'API — versioning (préfixe d'URL, stratégie de dépréciation et sunset), pagination
  (cursor-based et offset/limit avec métadonnées), format de réponse uniforme
  (`{ data, meta, error }`), codes HTTP sémantiques, idempotence (PUT/DELETE/PATCH +
  clé d'idempotence pour POST), OpenAPI 3.x (contrat first, schémas réutilisables),
  breaking changes (audit préalable, période de double support), webhooks (signature
  HMAC, réponse immédiate, traitement asynchrone, retry), rate limiting côté API
  (headers `X-RateLimit-*`, réponse 429 avec `Retry-After`)
- `docs/guides/authoring.md` : guide de création d'agents et de skills — décision
  agent vs skill (5 critères), checklist de qualité (frontmatter, corps, testabilité),
  exemples commentés d'agent et de skill bien formés, anti-patterns courants

### Changed

- Agent `developer-api` : skill `developer/dev-standards-api` ajouté dans le frontmatter
- Skill `developer/dev-standards-data` : section `Tests data` enrichie avec patterns
  dbt (tests natifs schema.yml + tests SQL personnalisés dans `tests/`), tests Airflow
  (structure DAG + tasks isolées avec mock des connexions), tests PySpark (fixtures
  locales SparkSession + `assertDataFrameEqual`), tests ML (shape des sorties,
  reproductibilité avec `random_state`, robustesse aux nulls)
- Agent `documentarian` : skill `posture/expert-posture` ajouté dans le frontmatter
- Agent `orchestrator` : skills `auditor/audit-ecodesign` et `auditor/audit-architecture`
  ajoutés dans la liste des domaines d'audit délégués
- Agent `reviewer` : skill `dev-standards-vuejs` retiré du frontmatter (le reviewer
  n'est pas spécialisé Vue.js — il applique les standards universels)
- Skill `orchestrator/orchestrator-protocol` : labels `auditor-ecodesign` et
  `auditor-architecture` ajoutés dans la table de routing d'audit
- `docs/architecture/agents.md` : total mis à jour (26 agents), ajout `developer-security`
  dans la famille developer/, note de distinction avec `developer-backend`
- `docs/architecture/skills.md` : ajout `dev-standards-api` et
  `dev-standards-security-hardening` dans le domaine developer/, matrice de dépendances
  mise à jour pour `developer-api` et `developer-security`

---


### Added

- Skill `posture/expert-posture` :
  exploration systématique des artefacts avant de répondre (annonce de ce qui a été consulté,
  identification des zones d'incertitude), recommandation contraire argumentée au format ⚠️
  (problème / alternative / pourquoi / trade-offs, formulation à la première personne),
  pause de confirmation 🛑 avant toute action irréversible ou structurellement impactante —
  injecté dans 11 agents : `auditor`, `auditor-security`, `auditor-performance`,
  `auditor-accessibility`, `auditor-ecodesign`, `auditor-architecture`, `auditor-privacy`,
  `auditor-observability`, `ux-designer`, `ui-designer`, `planner`
- `docs/guides/workflows.md` : refonte complète — guide de choix d'entrée (8 situations →
  agent recommandé), Scénario 1 réécrit pour l'architecture deux niveaux
  (orchestrator → phases design/audit → orchestrator-dev → developer-*), Scénario 2 mis à
  jour (7 sous-agents dont `auditor-observability`), Scénario 5 ajouté (designers standalone
  → orchestrator-dev), Scénario 6 ajouté (documentarian — documentation d'une feature livrée)
- `docs/architecture/overview.md` : diagramme "Workflow orchestrateur" mis à jour —
  architecture deux niveaux avec phases conception (ux/ui-designer), audit (auditor-*),
  implémentation (orchestrator-dev → developer-*) et CP-2 toujours pause absolue
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
  workflow Beads ticket par ticket, route vers 9 agents developer-*, supervise QA optionnel
  et review, 3 modes (manuel/semi-auto/auto), invocable standalone ou depuis l'orchestrator
- Skill `orchestrator/orchestrator-dev-protocol` : workflow Beads d'implémentation, matrice
  de routing developer-* (9 signaux → 9 agents), format checkpoints CP-1/CP-QA/CP-2/CP-3,
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

## [1.0.0] — 2026-03-29

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
