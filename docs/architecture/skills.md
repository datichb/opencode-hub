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
| `developer/beads-plan.md` | Tous les developer-*, planner, onboarder, designers, documentarian | Lecture et création de tickets Beads : `bd list`, `bd show`, `bd create`, `bd label list-all`, liens externes |
| `developer/beads-dev.md` | Tous les developer-*, designers, documentarian | Workflow exécuteur Beads : `bd update --claim`, `bd close --suggest-next`, règles `ai-delegated` |
| `developer/dev-standards-universal.md` | Tous les developer-*, reviewer | Clean Code, SOLID complet, TypeScript strict, nommage, structure |
| `developer/dev-standards-security.md` | Tous les developer-*, reviewer | Secrets/config, validation des inputs, injections (SQL/shell/LDAP), auth/autorisation, logs sans données sensibles, audit des dépendances |
| `developer/dev-standards-backend.md` | developer-backend, developer-fullstack, developer-api, reviewer | Architecture en couches, DTOs, services, repositories, sécurité API |
| `developer/dev-standards-frontend.md` | developer-frontend, developer-fullstack, reviewer | Séparation logique/présentation, performance, bundle, lazy loading |
| `developer/dev-standards-frontend-a11y.md` | developer-frontend, developer-fullstack, reviewer | WCAG 2.1 A/AA, sémantique HTML, ARIA, contrastes |
| `developer/dev-standards-vuejs.md` | developer-frontend, developer-fullstack | Composition API, `<script setup>`, Pinia, composables, Vue Router |
| `developer/dev-standards-testing.md` | developer-frontend, developer-backend, developer-fullstack, developer-api, developer-data, qa-engineer | Stratégie de tests, coverage, TDD, Vitest, pytest, PHPUnit |
| `developer/dev-standards-git.md` | Tous les developer-*, reviewer | Conventional Commits, branches, PR, messages de commit |
| `developer/dev-standards-data.md` | developer-data | Pipelines de données, ETL, ML, dbt, Airflow, qualité des données, tests dbt/Airflow/PySpark/ML |
| `developer/dev-standards-devops.md` | developer-devops | Docker, CI/CD, scripts shell (`set -euo pipefail`) |
| `developer/dev-standards-mobile.md` | developer-mobile | React Native, Flutter, Swift, Kotlin, patterns mobile, performance |
| `developer/dev-standards-platform.md` | developer-platform | Terraform, Pulumi, Kubernetes, Helm, GitOps (ArgoCD/Flux), secrets à l'échelle (Vault, ESO) |
| `developer/dev-standards-api.md` | developer-api | Versioning d'API, pagination, format de réponse uniforme, codes HTTP, idempotence, OpenAPI, breaking changes, webhooks, rate limiting |
| `developer/dev-standards-security-hardening.md` | developer-security | CORS, headers HTTP (CSP, HSTS, X-Frame-Options), bcrypt/argon2id, JWT (rotation, révocation), sessions (httpOnly/secure/sameSite), rate limiting, chiffrement AES-256-GCM |

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
| `auditor/audit-observability.md` | auditor-observability | Méthode RED (Rate/Errors/Duration), logs structurés, OpenTelemetry, SLOs/error budget, alerting (actionnable, runbooks), dashboards, grille des 5 questions |

---

## Domaine — `orchestrator/`

| Fichier | Agents qui l'utilisent | Contenu |
|---------|----------------------|---------|
| `orchestrator/orchestrator-protocol.md` | orchestrator | Workflow feature complet, matrice de routing (3 familles : design, auditor, dev via orchestrator-dev), format des checkpoints ([CP-0], [CP-spec], [CP-audit], [CP-feature]), gestion des cas particuliers |
| `orchestrator/orchestrator-dev-protocol.md` | orchestrator-dev | Workflow Beads ticket par ticket, matrice de routing developer-* (9 signaux → 9 agents), format des checkpoints ([CP-1] à [CP-3] + [CP-QA]), 3 modes (manuel/semi-auto/auto), format du compte rendu d'étape et du récap global |

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

## Domaine — `documentarian/`

Skills de documentation. Utilisés par l'agent `documentarian`.

| Fichier | Agents qui l'utilisent | Contenu |
|---------|----------------------|---------|
| `documentarian/doc-protocol.md` | documentarian | Exploration obligatoire avant rédaction, tableau d'adaptation en 4 situations (format conforme / améliorable / absent / partiel), routing par type de doc, checklist de lacunes, workflow Beads et direct |
| `documentarian/doc-standards.md` | documentarian | Framework Diataxis (4 quadrants), principes de lisibilité, structures type par document (README, how-to, référence), anti-patterns courants, critères de qualité, documentation fonctionnelle |
| `documentarian/doc-adr.md` | documentarian | Détection du format existant (Nygard / MADR / Y-Statements / maison), format MADR de référence, règles de nommage, statuts (proposed/accepted/deprecated/superseded), critères de création |
| `documentarian/doc-api.md` | documentarian | OpenAPI 3.x (squelette, endpoint, schemas réutilisables), codes HTTP, documentation narrative (guide d'utilisation, pagination, gestion des erreurs), identification et documentation des breaking changes |
| `documentarian/doc-changelog.md` | documentarian | Keep a Changelog (6 sections), SemVer (MAJOR/MINOR/PATCH), Conventional Commits → sections changelog, génération depuis git log, workflow de release, release notes format étendu |

---

## Domaine — `planning/`

| Fichier | Agents qui l'utilisent | Contenu |
|---------|----------------------|---------|
| `planning/planner.md` | planner | Phase 0 (exploration codebase + tickets existants + résumé de contexte), Phase 1 (questions contextualisées + déduction des priorités justifiées), Phase 2 (plan hiérarchique epics → tickets, règle >5 tickets), Phase 3 (création avec `--parent`, `--deps`, `--estimate`), Phase 4 (vérification `bd children`), gestion des aléas (scope change, scission, dépendance tardive, doublon) |
| `planning/project-discovery.md` | onboarder | Détection de stack (manifestes, CI, infra), exploration adaptative par profil (Vue, React, Node.js, Python, API, Data/ML, DevOps, Mobile), format du rapport de contexte (stack, architecture, patterns, 🔴/🟠/🟡, zones d'ombre, questions, carte agents), matrice de recommandation agents (prioritaires par risque + recommandés par stack + optionnels), protocole de mise à jour `projects.md` |

---

## Domaine — `designer/`

Skills de design. Utilisés par les agents `ux-designer` et `ui-designer`.

| Fichier | Agents qui l'utilisent | Contenu |
|---------|----------------------|---------|
| `designer/ux-protocol.md` | ux-designer | Heuristiques Nielsen (10 principes), grille des 5 questions UX, format user flow (nominal/alternatifs/erreurs), format spec UX avec critères d'acceptance, protocole d'audit friction |
| `designer/ui-protocol.md` | ui-designer | Tokens de design (couleurs, typographie, espacement, radius, ombres), format spec composant (variants/états/tokens/do-don't), règles de cohérence visuelle, protocole d'audit d'incohérences, échelle modulaire typographique |

---

## Domaine — `posture/`

Skills de posture transverse. Injectables dans tout agent nécessitant une posture d'expert.

| Fichier | Agents qui l'utilisent | Contenu |
|---------|----------------------|---------|
| `posture/expert-posture.md` | auditor, auditor-security, auditor-performance, auditor-accessibility, auditor-ecodesign, auditor-architecture, auditor-privacy, auditor-observability, onboarder, ux-designer, ui-designer, planner, documentarian | Exploration systématique avant de répondre (annonce des artefacts consultés, identification des zones d'incertitude), recommandation contraire argumentée (format ⚠️ avec problème/alternative/pourquoi/trade-offs, formulation à la première personne), pause de confirmation avant toute action à risque élevé (format 🛑 avec question binaire explicite) |

---

## Matrice de dépendances agents ↔ skills

```
orchestrator          → orchestrator/orchestrator-protocol
orchestrator-dev      → orchestrator/orchestrator-dev-protocol
onboarder             → planning/project-discovery, posture/expert-posture,
                         developer/beads-plan
planner               → developer/beads-plan, planning/planner, posture/expert-posture
reviewer              → dev-standards-universal, dev-standards-security,
                         dev-standards-backend,
                         dev-standards-frontend, dev-standards-frontend-a11y,
                         dev-standards-testing,
                         dev-standards-git, reviewer/review-protocol
qa-engineer           → dev-standards-universal, dev-standards-testing,
                         dev-standards-git, qa/qa-protocol
debugger              → debugger/debug-protocol
auditor               → auditor/audit-protocol, posture/expert-posture
auditor-security      → auditor/audit-protocol, auditor/audit-security, posture/expert-posture
auditor-performance   → auditor/audit-protocol, auditor/audit-performance, posture/expert-posture
auditor-accessibility → auditor/audit-protocol, auditor/audit-accessibility, posture/expert-posture
auditor-ecodesign     → auditor/audit-protocol, auditor/audit-ecodesign, posture/expert-posture
auditor-architecture  → auditor/audit-protocol, auditor/audit-architecture, posture/expert-posture
auditor-privacy       → auditor/audit-protocol, auditor/audit-privacy, posture/expert-posture
auditor-observability → auditor/audit-protocol, auditor/audit-observability, posture/expert-posture
ux-designer           → designer/ux-protocol, developer/beads-plan, developer/beads-dev, posture/expert-posture
ui-designer           → designer/ui-protocol, developer/beads-plan, developer/beads-dev, posture/expert-posture
developer-frontend    → dev-standards-universal, dev-standards-security,
                         dev-standards-frontend,
                         dev-standards-frontend-a11y, dev-standards-vuejs,
                         dev-standards-testing, dev-standards-git,
                         beads-plan, beads-dev
developer-backend     → dev-standards-universal, dev-standards-security,
                         dev-standards-backend,
                         dev-standards-testing, dev-standards-git,
                         beads-plan, beads-dev
developer-fullstack   → dev-standards-universal, dev-standards-security,
                         dev-standards-frontend,
                         dev-standards-frontend-a11y, dev-standards-vuejs,
                         dev-standards-backend, dev-standards-testing,
                         dev-standards-git, beads-plan, beads-dev
developer-data        → dev-standards-universal, dev-standards-security,
                         dev-standards-data, dev-standards-testing,
                         dev-standards-git, beads-plan, beads-dev
developer-devops      → dev-standards-universal, dev-standards-security,
                         dev-standards-devops,
                         dev-standards-git, beads-plan, beads-dev
developer-mobile      → dev-standards-universal, dev-standards-security,
                         dev-standards-mobile,
                         dev-standards-git, beads-plan, beads-dev
developer-api         → dev-standards-universal, dev-standards-security,
                         dev-standards-backend, dev-standards-api,
                         dev-standards-testing, dev-standards-git,
                         beads-plan, beads-dev
developer-platform    → dev-standards-universal, dev-standards-security,
                         dev-standards-platform,
                         dev-standards-git, beads-plan, beads-dev
developer-security    → dev-standards-universal, dev-standards-security,
                         dev-standards-security-hardening,
                         dev-standards-backend,
                         dev-standards-testing, dev-standards-git,
                         beads-plan, beads-dev
documentarian         → dev-standards-git, beads-plan, beads-dev,
                         documentarian/doc-protocol, documentarian/doc-standards,
                         documentarian/doc-adr, documentarian/doc-api,
                         documentarian/doc-changelog, posture/expert-posture
```
