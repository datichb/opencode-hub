# Référence des agents

28 agents au total, organisés en 7 familles.
Chaque agent est défini dans `agents/<famille>/<id>.md` avec un frontmatter déclarant ses métadonnées,
ses cibles et ses skills.

---

## Format d'un agent

```markdown
---
id: <identifiant-unique>
label: <NomAffiché>
description: <Description courte — visible dans les outils IA>
targets: [opencode, claude-code, vscode]
skills: [chemin/vers/skill, ...]
---

# <Titre>

<Corps de l'agent>
```

| Champ | Rôle |
|-------|------|
| `id` | Identifiant unique, utilisé par les adapters et `oc agent` |
| `label` | Nom affiché dans l'outil cible |
| `description` | Phrase courte décrivant le rôle — apparaît dans les listes d'agents |
| `targets` | Cibles supportées : `opencode`, `claude-code`, `vscode` |
| `skills` | Chemins relatifs à `skills/` — injectés dans l'ordre de déclaration |

---

## Famille — Coordinateurs

Agents qui pilotent d'autres agents sans jamais coder eux-mêmes.

### `orchestrator`

| | |
|--|--|
| **Label** | Orchestrator |
| **Fichier** | `agents/planning/orchestrator.md` |
| **Skills** | `orchestrator/orchestrator-protocol` |
| **Invocation** | `"Implémente [feature]"` / `"Prends en charge les tickets [IDs]"` |

Chef de projet IA. Pilote la réalisation complète d'une feature en mobilisant tous
les agents nécessaires : conception (ux-designer, ui-designer), audit (auditor-*),
implémentation (via orchestrator-dev). Impose des checkpoints explicites à chaque
phase. Ne code jamais.

Deux modes : **Mode A** (feature en langage naturel → délègue au planner) /
**Mode B** (tickets Beads existants → démarrage direct).

Ne route jamais directement vers les `developer-*` — délègue toujours à `orchestrator-dev`.

---

### `orchestrator-dev`

| | |
|--|--|
| **Label** | OrchestratorDev |
| **Fichier** | `agents/planning/orchestrator-dev.md` |
| **Skills** | `orchestrator/orchestrator-dev-protocol` |
| **Invocation** | `"Implémente les tickets [IDs]"` / `"Workflow dev sur [feature]"` |

Tech lead IA spécialisé dans le pilotage de l'implémentation. Prend en charge une
liste de tickets Beads prêts à implémenter, route vers les 8 agents `developer-*`,
supervise le QA optionnel et la review. Trois modes : `manuel` (défaut), `semi-auto`,
`auto`. Invocable standalone ou depuis l'`orchestrator`.

CP-2 (merge ou corriger ?) est toujours manuel dans tous les modes.

> Voir [ADR-006](./adr/006-orchestrator-configurable-mode.md) — les modes s'appliquent à `orchestrator-dev` uniquement.

---

### `auditor`

| | |
|--|--|
| **Label** | Auditeur |
| **Fichier** | `agents/auditor/auditor.md` |
| **Skills** | `auditor/audit-protocol` |
| **Invocation** | `"Audite [projet/périmètre]"` / `"Audit [domaine]"` |

Coordinateur d'audit multi-domaine. Qualifie la demande (audit complet / ciblé / express)
et délègue aux 7 sous-agents spécialisés. Produit une synthèse exécutive multi-domaines.
Lecture seule — ne modifie jamais de fichiers.

---

## Famille — Agents d'audit

Sous-agents de l'auditeur. Tous en lecture seule. Invocables directement ou via l'auditeur.

| Agent | Fichier | Domaine | Référentiels |
|-------|---------|---------|-------------|
| `auditor-security` | `agents/auditor/auditor-security.md` | Sécurité applicative | OWASP Top 10, CVE, RGS |
| `auditor-performance` | `agents/auditor/auditor-performance.md` | Performance web | Core Web Vitals, N+1, cache |
| `auditor-accessibility` | `agents/auditor/auditor-accessibility.md` | Accessibilité | WCAG 2.1 AA, RGAA 4.1 |
| `auditor-ecodesign` | `agents/auditor/auditor-ecodesign.md` | Éco-conception | RGESN, GreenIT, Écoindex |
| `auditor-architecture` | `agents/auditor/auditor-architecture.md` | Architecture & dette | SOLID, Clean Architecture |
| `auditor-privacy` | `agents/auditor/auditor-privacy.md` | Protection des données | RGPD, EDPB, CNIL |
| `auditor-observability` | `agents/auditor/auditor-observability.md` | Observabilité | Méthode RED, SLOs, OpenTelemetry, alerting |

Tous les agents d'audit injectent `auditor/audit-protocol` (format de rapport commun)
+ leur skill de domaine spécifique (`auditor/audit-<domaine>`).

---

## Famille — Agents développeurs

8 agents spécialisés par domaine technique. Tous suivent le même workflow Beads
(`bd claim → implémenter → tester → bd close`).

Skills communs à tous : `dev-standards-universal`, `dev-standards-security`, `dev-standards-git`, `dev-beads`.

| Agent | Fichier | Domaine | Skills spécifiques |
|-------|---------|---------|-------------------|
| `developer-frontend` | `agents/developer/developer-frontend.md` | UI, composants, Vue.js, CSS, a11y | `dev-standards-frontend`, `dev-standards-frontend-a11y`, `dev-standards-vuejs`, `dev-standards-testing` |
| `developer-backend` | `agents/developer/developer-backend.md` | Services, repositories, migrations | `dev-standards-backend`, `dev-standards-testing` |
| `developer-fullstack` | `agents/developer/developer-fullstack.md` | Features front + back | `dev-standards-frontend`, `dev-standards-backend`, `dev-standards-testing` |
| `developer-data` | `agents/developer/developer-data.md` | Pipelines, ETL, ML, dbt | `dev-standards-data` |
| `developer-devops` | `agents/developer/developer-devops.md` | Docker, CI/CD, scripts shell | `dev-standards-devops` |
| `developer-mobile` | `agents/developer/developer-mobile.md` | React Native, Flutter, iOS, Android | `dev-standards-mobile` |
| `developer-api` | `agents/developer/developer-api.md` | REST, GraphQL, webhooks | `dev-standards-backend`, `dev-standards-testing` |
| `developer-platform` | `agents/developer/developer-platform.md` | Terraform, K8s, Helm, GitOps, infra as code | `dev-standards-platform` |

> Voir [ADR-002](./adr/002-developer-segmentation.md) pour la décision de segmentation.

`developer-platform` se distingue de `developer-devops` : DevOps couvre Dockerfile,
docker-compose, GitHub Actions et scripts shell applicatifs ; Platform couvre
Terraform/Pulumi, manifests Kubernetes, Helm charts, ArgoCD/Flux.

---

## Famille — Agents de design

Agents de conception UX/UI. Travaillent en amont de l'implémentation.
Ne codent jamais. Invocables directement ou via l'`orchestrator`.

### `ux-designer`

| | |
|--|--|
| **Label** | UXDesigner |
| **Fichier** | `agents/design/ux-designer.md` |
| **Skills** | `designer/ux-protocol`, `developer/dev-beads` |
| **Invocation** | `"Analyse le flow de [feature]"` / `"Spec UX pour [ticket]"` / `"Audit UX de [écran]"` |

Expert en expérience utilisateur. Analyse les besoins, identifie les frictions,
produit des user flows textuels et des spécifications UX actionnables avec critères
d'acceptance. Pose au moins 2 questions de contexte avant de spécifier.
Lit et clôt les tickets Beads. Ne produit pas de maquettes graphiques.

---

### `ui-designer`

| | |
|--|--|
| **Label** | UIDesigner |
| **Fichier** | `agents/design/ui-designer.md` |
| **Skills** | `designer/ui-protocol`, `developer/dev-beads` |
| **Invocation** | `"Spec UI pour [composant]"` / `"Design system [projet]"` / `"Harmonise [écran]"` |

Expert en design d'interface. Définit les fondations d'un design system (tokens),
spécifie les composants visuels avec variants et états, produit des guidelines UI
actionnables pour `developer-frontend`. Utilise uniquement des tokens — jamais de
valeurs en dur. Propose toujours des options pour les décisions de direction artistique.

---

## Famille — Agents qualité

Agents dédiés à la qualité du code, invocables standalone ou via l'orchestrateur.

### `reviewer`

| | |
|--|--|
| **Label** | CodeReviewer |
| **Fichier** | `agents/quality/reviewer.md` |
| **Skills** | `dev-standards-universal`, `dev-standards-security`, `dev-standards-backend`, `dev-standards-frontend`, `dev-standards-frontend-a11y`, `dev-standards-vuejs`, `dev-standards-testing`, `dev-standards-git`, `reviewer/review-protocol` |
| **Invocation** | Diff collé / nom de branche / URL de PR + optionnellement `bd show <ID>` |

Analyse les diffs de PR/MR. Produit un rapport structuré par sévérité (Critique /
Majeur / Mineur / Suggestion / Points positifs). Lecture seule — ne modifie jamais
de fichiers.

---

### `qa-engineer`

| | |
|--|--|
| **Label** | QAEngineer |
| **Fichier** | `agents/quality/qa-engineer.md` |
| **Skills** | `dev-standards-universal`, `dev-standards-testing`, `dev-standards-git`, `qa/qa-protocol` |
| **Invocation** | `"Écris les tests pour la branche [X]"` / `"QA sur le ticket [ID]"` |

Écrit les tests manquants (unit / integration / E2E) à partir d'un diff ou d'un
ticket Beads. Produit un rapport de couverture avant/après. Ne modifie jamais
le code fonctionnel.

> Voir [ADR-004](./adr/004-qa-debugger-separation.md).

---

### `debugger`

| | |
|--|--|
| **Label** | Debugger |
| **Fichier** | `agents/quality/debugger.md` |
| **Skills** | `debugger/debug-protocol` |
| **Invocation** | `"Ce bug : [stacktrace]"` / `"Analyse ces logs : [logs]"` |

Diagnostique la cause racine d'un bug en 4 étapes (reproduction → isolation →
identification → hypothèse). Produit un rapport de diagnostic avec hypothèses
graduées. Crée un ticket Beads de correction après confirmation explicite.
Ne corrige jamais le bug.

> Voir [ADR-004](./adr/004-qa-debugger-separation.md).

---

## Famille — Agents de planification

### `planner`

| | |
|--|--|
| **Label** | ProjectPlanner |
| **Fichier** | `agents/planning/planner.md` |
| **Skills** | `developer/dev-beads`, `planner` |
| **Invocation** | Description d'une feature en langage naturel |

Consultant fonctionnel et technique qui analyse le contexte projet avant de planifier.
Explore la codebase (routes, modèles, composants selon la nature de la feature) et les
tickets Beads existants, produit un résumé de contexte, pose des questions contextualisées,
puis propose un plan hiérarchique (epics → tickets) avec priorités déduites et justifiées.

Crée les epics dans Beads si > 5 tickets (demande sinon), utilise `--parent` et `--deps`
pour la hiérarchie et les dépendances. Gère les aléas : scope change, ticket à scinder,
dépendance tardive, doublon. Ne code jamais.

---

## Famille — Agents de documentation

### `documentarian`

| | |
|--|--|
| **Label** | Documentarian |
| **Fichier** | `agents/documentation/documentarian.md` |
| **Skills** | `developer/dev-standards-git`, `developer/dev-beads`, `documentarian/doc-protocol`, `documentarian/doc-standards`, `documentarian/doc-adr`, `documentarian/doc-api`, `documentarian/doc-changelog` |
| **Invocation** | `"Documente [sujet]"` / `"Crée un ADR pour [décision]"` / `"Mets à jour le CHANGELOG"` / `"Qu'est-ce qui manque dans la doc ?"` |

Rédige et met à jour la documentation technique, fonctionnelle, architecturale, API
et les changelogs. Explore systématiquement la structure existante avant d'écrire.
S'adapte au format en place — recommande des améliorations sans les imposer.
Ne change jamais un format sans confirmation explicite.

Principe directeur : **explorer → adapter ou proposer → attendre si nécessaire → écrire**.

---

## Règles communes à tous les agents

- **Agents en lecture seule** : auditor-*, reviewer, debugger, ux-designer, ui-designer — ne modifient jamais de fichiers
- **Agents qui écrivent du code** : developer-*, qa-engineer — modifient uniquement les fichiers de leur domaine
- **Agents qui écrivent de la documentation** : documentarian — modifie uniquement les fichiers de documentation
- **Agents qui créent des tickets** : planner (tickets feature), debugger (tickets bug après confirmation)
- **Agents qui lisent les tickets** : tous peuvent faire `bd show <ID>` pour contextualiser leur travail
- **Agents coordinateurs** : orchestrator, orchestrator-dev, auditor — ne codent jamais, pilotent d'autres agents
