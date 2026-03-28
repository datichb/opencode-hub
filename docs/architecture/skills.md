# Référence des skills

Les skills sont des blocs Markdown injectés dans les agents au moment du déploiement.
Ils contiennent les protocoles détaillés, formats de sortie, checklists et règles
que les agents appliquent.

---

## Format d'un skill

```markdown
---
name: <nom-du-skill>
description: <Description courte — visible dans oc agent edit et oc skills list>
---

# Skill — <Titre>

<Corps du skill>
```

> La clé `name` est documentaire. Les scripts hub lisent uniquement `description`.
> Le chemin du fichier est la référence utilisée dans le frontmatter des agents.

---

## Domaine — `developer/`

Skills de standards de développement. Partagés entre les agents développeurs et le reviewer.

| Fichier | Agents qui l'utilisent | Contenu |
|---------|----------------------|---------|
| `developer/dev-beads.md` | Tous les developer-* | Workflow Beads complet : `bd list`, `bd show`, `bd claim`, `bd close --suggest-next` |
| `developer/dev-standards-universal.md` | Tous les developer-*, reviewer | Clean Code, SOLID complet, TypeScript strict, nommage, structure |
| `developer/dev-standards-backend.md` | developer-backend, developer-fullstack, developer-api, reviewer | Architecture en couches, DTOs, services, repositories, sécurité API |
| `developer/dev-standards-frontend.md` | developer-frontend, developer-fullstack, reviewer | Séparation logique/présentation, performance, bundle, lazy loading |
| `developer/dev-standards-frontend-a11y.md` | developer-frontend, developer-fullstack, reviewer | WCAG 2.1 A/AA, sémantique HTML, ARIA, contrastes |
| `developer/dev-standards-vuejs.md` | developer-frontend, developer-fullstack | Composition API, `<script setup>`, Pinia, composables, Vue Router |
| `developer/dev-standards-testing.md` | developer-frontend, developer-backend, developer-fullstack, developer-api, qa-engineer | Stratégie de tests, coverage, TDD, Vitest, pytest, PHPUnit |
| `developer/dev-standards-git.md` | Tous les developer-*, reviewer | Conventional Commits, branches, PR, messages de commit |
| `developer/dev-standards-data.md` | developer-data | Pipelines de données, ETL, ML, dbt, Airflow, qualité des données |
| `developer/dev-standards-devops.md` | developer-devops | Docker, CI/CD, scripts shell (`set -euo pipefail`), Terraform, sécurité infra |
| `developer/dev-standards-mobile.md` | developer-mobile | React Native, Flutter, Swift, Kotlin, patterns mobile, performance |

---

## Domaine — `auditor/`

Skills d'audit. Tous les agents auditor-* injectent `audit-protocol` + leur skill de domaine.

| Fichier | Agents qui l'utilisent | Contenu |
|---------|----------------------|---------|
| `auditor/audit-protocol.md` | auditor, tous les auditor-* | Format de rapport commun, 4 niveaux de criticité (🔴/🟠/🟡/💡), scoring /10, format des findings individuels |
| `auditor/audit-security.md` | auditor-security | OWASP Top 10, injections, secrets exposés, auth, CORS, CVE |
| `auditor/audit-performance.md` | auditor-performance | Core Web Vitals, LCP, CLS, TTI, requêtes N+1, cache, bundle |
| `auditor/audit-accessibility.md` | auditor-accessibility | WCAG 2.1 AA, RGAA 4.1, sémantique, ARIA, navigation clavier, contrastes |
| `auditor/audit-ecodesign.md` | auditor-ecodesign | RGESN, GreenIT, Écoindex, transfert de données, ressources, obsolescence |
| `auditor/audit-architecture.md` | auditor-architecture | SOLID, Clean Architecture, dette technique, couplage, cohésion |
| `auditor/audit-privacy.md` | auditor-privacy | RGPD articles 5/6/17/25/32, EDPB, CNIL, minimisation, consentement |

---

## Domaine — `orchestrator/`

| Fichier | Agents qui l'utilisent | Contenu |
|---------|----------------------|---------|
| `orchestrator/orchestrator-protocol.md` | orchestrator | Workflow ticket par ticket, matrice de routing (7 signaux → 7 agents), format des 5 checkpoints ([CP-0] à [CP-3] + [CP-QA]), format du compte rendu d'étape et du récap global, gestion des cas particuliers |

---

## Domaine — `qa/`

| Fichier | Agents qui l'utilisent | Contenu |
|---------|----------------------|---------|
| `qa/qa-protocol.md` | qa-engineer | Typologie des tests (unit/integration/E2E/composants), outils par stack, checklist systématique (nominal/erreur/edge cases/acceptance), format du rapport de couverture, structure type AAA |

---

## Domaine — `debugger/`

| Fichier | Agents qui l'utilisent | Contenu |
|---------|----------------------|---------|
| `debugger/debug-protocol.md` | debugger | Méthodologie en 4 étapes, lecture de stacktraces et logs, format du rapport de diagnostic avec hypothèses graduées, protocole de création de ticket Beads |

---

## Domaine — `reviewer/`

| Fichier | Agents qui l'utilisent | Contenu |
|---------|----------------------|---------|
| `reviewer/review-protocol.md` | reviewer | Format du rapport de review (Critique/Majeur/Mineur/Suggestion/Points positifs/Hors scope), 4 niveaux de sévérité, checklist systématique en 6 catégories, format des commentaires individuels, mode "audit complet" |

---

## Domaine — `planner`

| Fichier | Agents qui l'utilisent | Contenu |
|---------|----------------------|---------|
| `planner.md` | planner | Workflow interactif en 4 étapes + étape 3.5 (délégation ai-delegated), commandes `bd` autorisées (`bd create`, `bd update`, `bd list`, `bd label`), format de proposition de découpage, exemple complet |

> Note : ce skill est à la racine de `skills/` (pas dans un sous-dossier) car il est
> antérieur à la convention de sous-dossiers par domaine.

---

## Matrice de dépendances agents ↔ skills

```
orchestrator          → orchestrator/orchestrator-protocol
planner               → planner
reviewer              → dev-standards-universal, dev-standards-backend,
                         dev-standards-frontend, dev-standards-frontend-a11y,
                         dev-standards-vuejs, dev-standards-testing,
                         dev-standards-git, reviewer/review-protocol
qa-engineer           → dev-standards-universal, dev-standards-testing,
                         dev-standards-git, qa/qa-protocol
debugger              → debugger/debug-protocol
auditor               → auditor/audit-protocol
auditor-security      → auditor/audit-protocol, auditor/audit-security
auditor-performance   → auditor/audit-protocol, auditor/audit-performance
auditor-accessibility → auditor/audit-protocol, auditor/audit-accessibility
auditor-ecodesign     → auditor/audit-protocol, auditor/audit-ecodesign
auditor-architecture  → auditor/audit-protocol, auditor/audit-architecture
auditor-privacy       → auditor/audit-protocol, auditor/audit-privacy
developer-frontend    → dev-standards-universal, dev-standards-frontend,
                         dev-standards-frontend-a11y, dev-standards-vuejs,
                         dev-standards-testing, dev-standards-git, dev-beads
developer-backend     → dev-standards-universal, dev-standards-backend,
                         dev-standards-testing, dev-standards-git, dev-beads
developer-fullstack   → dev-standards-universal, dev-standards-frontend,
                         dev-standards-backend, dev-standards-testing,
                         dev-standards-git, dev-beads
developer-data        → dev-standards-universal, dev-standards-data,
                         dev-standards-git, dev-beads
developer-devops      → dev-standards-universal, dev-standards-devops,
                         dev-standards-git, dev-beads
developer-mobile      → dev-standards-universal, dev-standards-mobile,
                         dev-standards-git, dev-beads
developer-api         → dev-standards-universal, dev-standards-backend,
                         dev-standards-testing, dev-standards-git, dev-beads
```
