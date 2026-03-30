---
name: project-discovery
description: Protocole d'exploration adaptative d'un projet existant — détecte la stack, explore les fichiers structurants selon le profil détecté, produit un rapport de contexte structuré (stack, architecture, patterns, points d'attention 🔴/🟠/🟡, zones d'ombre, questions de clarification, carte des agents recommandés priorisée par stack + risques détectés).
---

# Skill — Project Discovery

## Rôle

Ce skill définit le protocole d'exploration d'un projet existant pour un agent
qui arrive sans contexte préalable. Il couvre la détection de stack, l'exploration
adaptative des fichiers structurants, et la production d'un rapport de contexte
honnête avec une carte d'agents recommandés priorisée.

Il complète `posture/expert-posture` (qui définit la posture d'exploration)
en fournissant le protocole concret : quoi lire, dans quel ordre, comment rapporter.

---

## ÉTAPE 1 — Détecter la stack

**Annoncer avant d'explorer :**
> "Je vais lire les fichiers de configuration à la racine pour identifier la stack."

Lire dans cet ordre (s'arrêter dès que suffisant) :

### Manifestes de dépendances

```
package.json          → Node.js / JavaScript / TypeScript
pyproject.toml        → Python (Poetry, PDM, Hatch)
requirements.txt      → Python (pip classique)
go.mod                → Go
Gemfile               → Ruby
composer.json         → PHP
Cargo.toml            → Rust
pom.xml               → Java / Kotlin (Maven)
build.gradle          → Java / Kotlin (Gradle)
mix.exs               → Elixir
```

### Tooling et versions

```
.tool-versions        → versions exactes (asdf)
.nvmrc / .node-version → version Node.js
.python-version       → version Python
```

### CI / CD

```
.github/workflows/    → GitHub Actions (lire les fichiers *.yml)
.gitlab-ci.yml        → GitLab CI
Jenkinsfile           → Jenkins
.circleci/config.yml  → CircleCI
```

### Infra et conteneurisation

```
docker-compose.yml / docker-compose.yaml  → services, bases de données, dépendances
Dockerfile                                → image de base, runtime
terraform/                                → infrastructure as code
k8s/ ou kubernetes/ ou manifests/         → orchestration Kubernetes
helm/                                     → Helm charts
```

### Détection du profil applicatif

À partir des dépendances lues dans `package.json` (ou équivalent) :

| Dépendance détectée | Profil |
|--------------------|--------|
| `vue`, `@vue/core` | Frontend Vue.js |
| `react`, `react-dom` | Frontend React |
| `@angular/core` | Frontend Angular |
| `next` | Frontend Next.js (SSR) |
| `nuxt` | Frontend Nuxt.js (SSR) |
| `express`, `fastify`, `koa`, `hapi` | Backend Node.js |
| `@nestjs/core` | Backend NestJS |
| `django`, `flask`, `fastapi` | Backend Python |
| `laravel`, `symfony` | Backend PHP |
| `rails` | Backend Ruby on Rails |
| `dbt-core`, `apache-airflow`, `pyspark` | Data / ML |
| `react-native`, `expo` | Mobile React Native |
| `flutter` (pubspec.yaml) | Mobile Flutter |
| `graphql`, `@apollo/server`, `strawberry` | API GraphQL |
| `openapi`, `swagger-ui` | API REST documentée |

**Profil fullstack** : si frontend ET backend sont détectés dans le même dépôt (monorepo).

---

## ÉTAPE 2 — Explorer adaptativement

Une fois le profil identifié, cibler les fichiers structurants selon le profil.
**Annoncer ce qui va être lu avant chaque section.**

### Profil Frontend Vue.js

```
src/router/index.ts (ou router.ts)    → routes déclarées, lazy loading
src/stores/ (ou src/store/)           → état global (Pinia / Vuex)
src/composables/                      → logique réutilisable
src/components/                       → 3-5 composants représentatifs
src/layouts/                          → layouts globaux
vite.config.ts (ou vue.config.js)     → configuration du build
.env.example (ou .env.local)          → variables d'environnement
```

### Profil Frontend React / Next.js

```
src/app/ (ou pages/)                  → structure des routes
src/components/                       → 3-5 composants représentatifs
src/hooks/                            → custom hooks
src/store/ ou src/context/            → état global
next.config.js / vite.config.ts       → configuration
.env.example                          → variables d'environnement
```

### Profil Backend Node.js

```
src/routes/ (ou app.ts / server.ts)   → routes déclarées, middlewares
src/controllers/ (ou src/handlers/)   → contrôleurs
src/services/                         → logique métier
src/models/ (ou src/entities/)        → modèles de données
src/middleware/                       → authentification, validation, logging
migrations/ (ou db/migrations/)       → migrations en attente ou récentes
.env.example                          → variables d'environnement
```

### Profil Backend Python

```
Module principal (src/, app/, [nom_projet]/)   → structure des packages
Routes / views (views.py, routes.py, api/)     → endpoints exposés
models.py (ou models/)                         → modèles de données
migrations/                                    → migrations
settings.py (ou config/, .env.example)         → configuration
tests/                                         → organisation des tests
requirements.txt / pyproject.toml              → dépendances (versions)
```

### Profil API REST / GraphQL

```
openapi.yaml (ou swagger.yaml, api-docs/)      → contrat d'API
schema.graphql (ou src/schema/)                → schéma GraphQL
src/controllers/ (ou src/resolvers/)           → handlers
src/middleware/auth*                           → auth et autorisation
```

### Profil Data / ML

```
dbt/models/                           → modèles dbt, structure
dbt/tests/ (ou tests/)                → tests de qualité des données
airflow/dags/                         → DAGs (lire 1-2 représentatifs)
notebooks/                            → notebooks (titres + premières cellules)
pipelines/ (ou src/pipelines/)        → pipelines ETL
models/ (ML) ou src/models/           → scripts d'entraînement, modèles
data/                                 → structure des données (pas le contenu)
```

### Profil DevOps / Platform

```
.github/workflows/                    → tous les workflows CI/CD
Dockerfile(s)                         → image(s), multi-stage build
docker-compose.yml                    → services et dépendances
terraform/                            → modules, main.tf, variables.tf
k8s/ ou helm/                         → manifests, values.yaml
scripts/                              → scripts de déploiement
```

### Profil Mobile

```
src/screens/ (ou lib/screens/)        → écrans principaux
src/navigation/ (ou lib/navigation/)  → stack de navigation
src/components/ (ou lib/widgets/)     → composants réutilisables
src/services/ (ou lib/services/)      → appels API, services
android/ (ou ios/)                    → configuration native
pubspec.yaml (Flutter) / package.json → dépendances et versions
```

### Complément transversal (tous profils)

Si présents, lire également :

```
README.md                              → description, setup, conventions
CONTRIBUTING.md                        → processus de contribution
docs/ ou doc/                          → documentation technique
adr/ (ou docs/architecture/adr/)       → décisions architecturales
.eslintrc* / .prettierrc*              → conventions de code
jest.config.ts / vitest.config.ts      → configuration des tests
```

---

## ÉTAPE 3 — Lire les tickets et ADRs existants

Si Beads est initialisé (`.beads/` présent à la racine du projet) :

```bash
# Tickets ouverts — état du backlog
bd list --status open --json

# Tickets récemment clos — ce qui vient d'être livré
bd list --status closed --limit 10 --json
```

Identifier :
- Y a-t-il des tickets de dette / bug / chore non traités en nombre inhabituel ?
- Y a-t-il des patterns récurrents (ex: concentration de bugs sur un module) ?

---

## ÉTAPE 4 — Produire le rapport de contexte

Format imposé, à respecter strictement :

````markdown
## Rapport de contexte — [Nom du projet] — [date]

### Stack

| Catégorie | Technologies détectées |
|-----------|----------------------|
| Langage(s) | [ex: TypeScript 5.x, Python 3.11] |
| Framework(s) | [ex: Vue 3 + Nuxt 4, FastAPI 0.110] |
| Base(s) de données | [ex: PostgreSQL 15, Redis 7] |
| Infrastructure | [ex: Docker, GitHub Actions, Terraform] |
| Tests | [ex: Vitest, pytest, Playwright] |

### Architecture

[Description de la structure : monorepo / monolithe / microservices / BFF / etc.]
[Découpage en couches ou modules observé]
[Communication entre couches (HTTP, événements, queues)]

### Patterns dominants

- [Pattern 1 observé — ex: "Repository pattern pour l'accès aux données"]
- [Pattern 2 observé — ex: "Composables Vue pour la logique partagée"]
- [Convention observée — ex: "Conventional Commits respectés dans le git log"]

### Points d'attention

🔴 **Critiques**
- [Zone à risque élevé — citer le fichier / pattern observé]

🟠 **Importants**
- [Zone fragile — dette technique notable, couplage fort, absence de tests]

🟡 **Améliorations**
- [Opportunité — performance, qualité, éco-conception, accessibilité]

*(Section vide si aucun point détecté — ne pas inventer)*

### Zones d'ombre

- [Ce que l'exploration n'a pas permis de résoudre]
- [ex: "Logique d'authentification dans un service externe non accessible"]
- [ex: "Pas de README — architecture générale non documentée"]

*(Section vide si tout est lisible)*

### Questions de clarification

1. [Question 1 — basée sur une zone d'ombre concrète]
2. [Question 2 — basée sur un choix technique ambigu]
3. [...]

*(5 questions maximum — prioriser les plus impactantes)*

### Agents recommandés

#### Prioritaires — zones à risque détectées

| Agent | Pourquoi | Invocation suggérée |
|-------|----------|---------------------|
| `auditor-security` | [observation concrète] | `"Audite la sécurité de ce projet"` |
| `developer-security` | À invoquer après l'audit pour corriger les failles | `"Implémente le hardening suite à l'audit sécurité"` |

*(Section absente si aucun 🔴/🟠 pertinent)*

#### Recommandés — stack détectée

| Agent | Pourquoi | Invocation suggérée |
|-------|----------|---------------------|
| `developer-frontend` | [stack frontend détectée] | `"Implémente [feature frontend]"` |
| `developer-backend` | [stack backend détectée] | `"Implémente [feature backend]"` |

#### Optionnels — selon les ambitions du projet

| Agent | Pourquoi | Invocation suggérée |
|-------|----------|---------------------|
| `auditor-accessibility` | [observation] | `"Audite l'accessibilité"` |
| `auditor-ecodesign` | [observation] | `"Audite l'éco-conception"` |

---

> Ces invocations sont des suggestions — c'est à toi de décider quand et si tu les lances.
````

---

## Matrice de recommandation des agents

### Agents prioritaires (activés par les points d'attention 🔴/🟠)

| Signal détecté | Agents prioritaires |
|---------------|---------------------|
| Secrets en dur dans le code | `auditor-security` → `developer-security` |
| Pas de validation des inputs côté serveur | `auditor-security` → `developer-security` |
| Dépendances avec versions très anciennes (potentiel CVE) | `auditor-security` |
| Hashing faible ou absent (MD5, SHA1, plain text) | `auditor-security` → `developer-security` |
| CORS trop permissif (`*`) ou absent | `auditor-security` → `developer-security` |
| Données personnelles sans chiffrement ni contrôle d'accès | `auditor-privacy` |
| Pas de tests (dossier `tests/` vide ou absent) | `qa-engineer` |
| Ratio fichiers source / fichiers test très déséquilibré | `qa-engineer` |
| Requêtes N+1 visibles dans les relations ORM | `auditor-performance` |
| Bundle non optimisé (pas de lazy loading, assets non compressés) | `auditor-performance` |
| Pas de logs structurés / monitoring absent | `auditor-observability` |
| Imports circulaires, God classes, couplage fort évident | `auditor-architecture` |
| Migrations en attente non appliquées | `developer-backend` (traitement prioritaire) |

### Agents recommandés (activés par la stack)

| Stack détectée | Agent recommandé |
|---------------|-----------------|
| Vue.js / Nuxt.js | `developer-frontend` |
| React / Next.js / Angular | `developer-frontend` |
| Node.js / NestJS / Express / Fastify | `developer-backend` |
| Python / Django / FastAPI / Flask | `developer-backend` |
| PHP / Laravel / Symfony | `developer-backend` |
| Ruby on Rails | `developer-backend` |
| Frontend + backend dans le même dépôt | `developer-fullstack` |
| API REST documentée (OpenAPI) | `developer-api` |
| API GraphQL | `developer-api` |
| dbt / Airflow / PySpark / notebooks | `developer-data` |
| Docker / GitHub Actions / scripts CI | `developer-devops` |
| Terraform / Kubernetes / Helm / ArgoCD | `developer-platform` |
| React Native / Expo | `developer-mobile` |
| Flutter | `developer-mobile` |
| Parcours utilisateur complexe non documenté | `ux-designer` |
| Incohérences visuelles / absence de design system | `ui-designer` |

### Agents optionnels (selon les ambitions)

| Observation | Agent optionnel |
|-------------|----------------|
| Aucun attribut ARIA visible, sémantique HTML absente | `auditor-accessibility` |
| Assets lourds, aucune optimisation visible | `auditor-ecodesign` |
| SLOs non définis, alerting absent | `auditor-observability` |
| Architecture non documentée, pas d'ADR | `documentarian` |

---

## Mise à jour de `projects.md`

Si le champ `Stack` du projet est absent ou trop générique dans `projects.md` :

**⏸️ PAUSE — Proposer :**
> "J'ai détecté la stack suivante : [stack]. Souhaites-tu que je mette à jour le champ `Stack` dans `projects.md` ? (oui / non)"

**Uniquement si l'utilisateur valide :**
Mettre à jour le champ `Stack` dans la section du projet concerné dans `projects.md`.

**Ne jamais modifier `projects.md` sans confirmation explicite.**

---

## Règles de conduite

- **Annoncer avant d'explorer** : toujours dire ce qui va être lu avant de le lire
- **Honnêteté sur les zones d'ombre** : si quelque chose n'est pas lisible depuis la codebase, le dire — ne pas inventer
- **Points d'attention basés sur des observations concrètes** : ne jamais signaler un 🔴 sans citer le fichier, la ligne ou le pattern observé
- **Agents prioritaires avant recommandés** : ne pas noyer l'utilisateur dans une liste plate
- **Invocations suggérées, jamais exécutées** : proposer, jamais déclencher un autre agent automatiquement
- **Rapport concis** : viser 1-2 pages — si le projet est simple, le rapport est court
