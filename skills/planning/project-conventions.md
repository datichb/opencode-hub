---
name: project-conventions
description: Protocole de détection et documentation des conventions d'un projet — nommage, architecture, libs, Git, tests, linting, config, patterns équipe. Produit CONVENTIONS.md à la racine du projet comme référentiel vivant pour les agents et les développeurs.
---

# Skill — Project Conventions

## Rôle

Ce skill définit comment détecter, structurer et écrire les conventions réelles
d'un projet dans un fichier `CONVENTIONS.md`. Ce fichier sert de référentiel
partagé entre les agents (qui le lisent en début de session) et les développeurs
(qui s'en servent comme guide de contribution rapide).

Il complète `planning/project-discovery` : là où l'onboarding dresse un état des
lieux ponctuel du projet, les conventions documentent les règles stables qui
gouvernent comment le code est écrit.

---

## Quand produire CONVENTIONS.md

- **À la fin d'un onboarding** — après avoir exploré le projet, produire les
  conventions détectées en bonus
- **Via `oc conventions <PROJECT_ID>`** — mise à jour ciblée des conventions seules
- **Sur demande explicite** — "Documente les conventions de ce projet"

---

## DÉTECTION — Quoi lire et dans quel ordre

### 1. Config de linting et formatting

Ces fichiers sont la source de vérité la plus fiable sur les conventions de code.
Les lire en priorité.

```
.eslintrc / .eslintrc.js / .eslintrc.json / .eslintrc.cjs
eslint.config.js / eslint.config.mjs          → nouvelle config flat ESLint
.prettierrc / .prettierrc.js / .prettierrc.json
.prettierignore
.stylelintrc / stylelint.config.js
.editorconfig                                  → indentation, line endings, charset
biome.json                                     → Biome (remplace ESLint + Prettier)
ruff.toml / pyproject.toml [tool.ruff]         → Python (ruff)
.flake8 / setup.cfg [flake8]                   → Python (flake8)
mypy.ini / pyproject.toml [tool.mypy]          → Python (mypy)
```

**Ce qu'on en extrait :**
- Indentation : espaces / tabs, taille
- Guillemets : simple / double
- Semicolons : oui / non
- Longueur de ligne maximale
- Règles ESLint activées / désactivées notables
- Extensions / plugins actifs (vue, react, import, etc.)

---

### 2. Configuration TypeScript / langage

```
tsconfig.json / tsconfig.base.json
.babelrc / babel.config.js
.swcrc
pyproject.toml / setup.cfg          → Python
go.mod                              → Go
Cargo.toml                          → Rust
```

**Ce qu'on en extrait :**
- `strict` mode activé ou non
- `paths` (alias d'imports configurés)
- `target` / `module` (compatibilité)
- Decorators activés (NestJS, TypeORM)
- Modules Python : organisation des packages, PEP 8 strict ou non

---

### 3. Dépendances et librairies choisies

Lire `package.json` (ou `pyproject.toml`, `Gemfile`, `go.mod`, etc.) :

**Ce qu'on en extrait :**
- Framework(s) UI principal(aux)
- State management retenu (Pinia, Zustand, RTK, MobX, etc.)
- Framework de routing
- Lib de requêtes HTTP (axios, ky, fetch natif, TanStack Query, SWR, etc.)
- Framework de test (Vitest, Jest, pytest, etc.)
- Lib de validation (Zod, Yup, Valibot, Pydantic, etc.)
- ORM / query builder (Prisma, Drizzle, TypeORM, SQLAlchemy, etc.)
- Lib de dates (date-fns, Temporal, dayjs, moment — et laquelle est exclue)
- UI lib / design system (Vuetify, shadcn, Tailwind, MUI, etc.)
- Tout ce qui est dans `devDependencies` de structurel

---

### 4. Conventions Git

```
.commitlintrc / commitlint.config.js     → règles de commits
.husky/ / .lefthook.yml                  → hooks pre-commit, pre-push
CONTRIBUTING.md                          → processus de contribution
.github/PULL_REQUEST_TEMPLATE.md         → template de PR
.github/CODEOWNERS                       → ownership des fichiers
```

Lire aussi le git log récent (20 derniers commits) :
```bash
git log --oneline -20
```

**Ce qu'on en extrait :**
- Format de commit : Conventional Commits / autre / libre
- Types de commit utilisés en pratique
- Convention de nommage des branches observée (`feat/`, `fix/`, `chore/`, etc.)
- Processus de PR (squash / merge / rebase)
- Reviewers obligatoires / CODEOWNERS

---

### 5. Nommage — inféré de la codebase

Lire 5 à 10 fichiers représentatifs du projet (selon le profil détecté) :

```
src/components/           → nommage des composants (PascalCase, kebab-case ?)
src/composables/ ou hooks/→ préfixe use* ?
src/services/             → nommage des services (suffix Service ?)
src/stores/               → nommage des stores
src/utils/ ou src/lib/    → nommage des utilitaires
src/types/ ou src/interfaces/ → nommage des types (suffix Type / Interface / aucun ?)
test files                → suffixe .test.ts / .spec.ts ?
```

**Ce qu'on extrait par observation :**
- Convention de nommage des fichiers : camelCase, PascalCase, kebab-case
- Convention de nommage des composants / classes / fonctions
- Structure des dossiers : feature-based / layer-based / mixed
- Co-location des tests ou dossier `tests/` séparé

---

### 6. Structure et architecture

Lire la structure des dossiers `src/` (ou racine) :

**Ce qu'on extrait :**
- Organisation : feature-based / layer-based / domain-driven
- Couches présentes (controllers, services, repositories, etc.)
- Monorepo ou monopackage (workspaces ?)
- Conventions de barrel exports (`index.ts`)
- Conventions d'imports : relatifs vs absolus (alias `@/`)

---

### 7. Standards de test

```
vitest.config.ts / jest.config.ts / jest.config.js
pytest.ini / pyproject.toml [tool.pytest]
.nycrc / c8 / coverage config
playwright.config.ts / cypress.config.ts
```

**Ce qu'on extrait :**
- Framework de test unitaire et d'intégration
- Framework de test E2E (si présent)
- Seuil de couverture configuré
- Convention de nommage des tests (`it should` / `doit … quand` / etc.)
- Co-location des tests ou dossier séparé

---

### 8. Config et secrets

```
.env.example / .env.local.example
.env.schema (si existant)
```

**Ce qu'on extrait :**
- Variables d'environnement requises et leur format attendu
- Convention de nommage : `UPPER_SNAKE_CASE`, préfixe `VITE_`, `NEXT_PUBLIC_`, etc.
- Secrets jamais dans le code (valider que `.env` est dans `.gitignore`)

---

### 9. Patterns spécifiques à l'équipe

Lire (si présents) :
```
CONTRIBUTING.md
README.md              → section "Development" ou "Contributing"
docs/                  → guides de développement internes
adr/                   → décisions architecturales (patterns imposés)
```

Et observer dans la codebase :
- Patterns de gestion d'erreurs (classes d'erreur custom, Result type, etc.)
- Patterns d'authentification (middleware, guards, décorateurs)
- Patterns de logging (lib, format, niveaux)
- Patterns de feature flags (si présents)

---

## FORMAT DE CONVENTIONS.MD

Structure exacte à respecter lors de l'écriture du fichier :

```markdown
# Conventions — <NOM_PROJET>
> Généré le <DATE> — mis à jour via : oc conventions <PROJECT_ID>
> Ce fichier est un référentiel vivant. Les agents s'en servent comme source de
> vérité pour respecter les conventions du projet.

---

## Linting & formatting

- **Formatter** : <Prettier / Biome / ruff / gofmt / aucun>
- **Linter** : <ESLint v9 flat config / ruff / golangci-lint / aucun>
- **Indentation** : <2 espaces / 4 espaces / tabs>
- **Guillemets** : <simple / double>
- **Semicolons** : <oui / non>
- **Longueur de ligne** : <80 / 100 / 120 / non configurée>
- **Plugins notables** : <liste>

---

## Langage & typage

- **Langage** : <TypeScript 5.x strict / Python 3.12 + mypy / Go 1.22 / etc.>
- **Mode strict** : <oui / non — préciser les options clés>
- **Alias d'imports** : <`@/` → `src/` / `~` → `src/` / aucun>
- **Particularités** : <decorators activés, paths configurés, etc.>

---

## Librairies & dépendances

| Rôle | Lib retenue | À ne pas utiliser |
|------|------------|-------------------|
| State management | <Pinia / Zustand / RTK / ...> | <moment, lodash, etc. si exclus> |
| Requêtes HTTP | <TanStack Query / axios / fetch natif / ...> | |
| Validation | <Zod / Valibot / Yup / Pydantic / ...> | |
| ORM / DB | <Prisma / Drizzle / SQLAlchemy / ...> | |
| Tests unitaires | <Vitest / Jest / pytest / ...> | |
| Tests E2E | <Playwright / Cypress / aucun> | |
| UI / Design system | <shadcn-vue / Vuetify / Tailwind / ...> | |
| Dates | <date-fns / Temporal / dayjs / ...> | <moment — interdit> |

---

## Nommage

| Élément | Convention | Exemple |
|---------|-----------|---------|
| Fichiers composants | <PascalCase / kebab-case> | `UserCard.vue` / `user-card.vue` |
| Fichiers utilitaires | <camelCase / kebab-case> | `formatDate.ts` / `format-date.ts` |
| Composants / Classes | PascalCase | `UserCard`, `AuthService` |
| Fonctions / méthodes | camelCase | `getUserById`, `formatDate` |
| Composables / hooks | camelCase préfixé `use` | `useAuth`, `useUserStore` |
| Stores | camelCase préfixé `use` | `useUserStore`, `useCartStore` |
| Types / Interfaces | PascalCase <sans / avec suffix> | `User`, `UserDto`, `IUserService` |
| Variables d'env | UPPER_SNAKE_CASE <+ préfixe> | `VITE_API_URL`, `DATABASE_URL` |
| Fichiers de test | <même nom + `.spec.ts` / `.test.ts`> | `UserCard.spec.ts` |
| Branches Git | <convention observée> | `feat/bd-42-user-auth` |

---

## Architecture & structure

- **Organisation** : <feature-based / layer-based / domain-driven>
- **Couches** : <Controller → Service → Repository / MVC / MVVM / etc.>
- **Monorepo** : <oui (workspaces: ...) / non>
- **Barrel exports** : <oui (`index.ts` systématique) / non>
- **Tests** : <co-localisés (`*.spec.ts` à côté des sources) / dossier `tests/` séparé>
- **Structure observée** :
  ```
  src/
  ├── <dossiers principaux avec leur rôle>
  ```

---

## Conventions Git

- **Format de commit** : <Conventional Commits / libre / autre>
- **Types utilisés** : <feat, fix, chore, docs, refactor, test, perf, ci>
- **Branches** : <convention observée — ex: `feat/<ticket-id>-<description>`>
- **PR/MR** : <squash merge / merge commit / rebase / non configuré>
- **Hooks** : <pre-commit (lint-staged) / pre-push (tests) / aucun>

---

## Standards de test

- **Framework unitaire** : <Vitest / Jest / pytest / ...>
- **Framework E2E** : <Playwright / Cypress / aucun>
- **Couverture minimale** : <X% configuré / non configuré>
- **Convention de nommage** : <`it('doit X quand Y')` / `test('should X')` / libre>
- **Co-location** : <oui / non>
- **Mocking** : <vi.mock / jest.mock / pytest monkeypatch / MSW pour les APIs>

---

## Config & secrets

- **Variables d'env requises** : <liste depuis `.env.example`>
- **Préfixe exposé côté client** : <`VITE_` / `NEXT_PUBLIC_` / `NUXT_PUBLIC_` / aucun>
- **`.env` dans `.gitignore`** : <oui / ⚠️ non — à corriger>
- **Gestion des secrets** : <vault / GitHub secrets / .env local uniquement>

---

## Patterns spécifiques à l'équipe

<Décrire ici les patterns observés qui ne rentrent pas dans les catégories
précédentes — gestion d'erreurs custom, pattern Result, middleware d'auth,
feature flags, conventions de logging, etc.>

<Vide si aucun pattern spécifique détecté — ne pas inventer.>

---

## Zones d'ombre

<Ce qui n'a pas pu être déterminé depuis la codebase — config manquante,
dossiers non accessibles, conventions implicites non documentées.>

<Vide si tout a pu être déterminé.>
```

---

## RÈGLES DE CONDUITE

- **Baser chaque convention sur un fichier réellement lu** — ne jamais inventer
  une convention sans source (fichier de config, fichier de code, ADR)
- **Citer la source entre parenthèses** quand c'est utile : ex. "(observé dans
  `eslint.config.js`)", "(inféré depuis `src/composables/`)"
- **Signaler les incohérences** : si `.eslintrc` dit single quotes mais le code
  utilise double quotes → noter l'écart dans "Zones d'ombre"
- **Vide plutôt qu'inventé** : une section vide avec "Non configuré" est préférable
  à une convention supposée
- **Mise à jour incrémentale** : si `CONVENTIONS.md` existe déjà, proposer de
  mettre à jour uniquement les sections concernées plutôt que de tout réécrire

---

## RÈGLE DE LECTURE POUR LES AGENTS

Tout agent qui génère du code sur un projet doit, en début de session :

1. Vérifier si `CONVENTIONS.md` existe à la racine du projet
2. Si oui → le lire intégralement avant toute génération de code
3. Appliquer ses conventions **en priorité sur les standards génériques du hub**
4. En cas de conflit entre `CONVENTIONS.md` et un `dev-standards-*.md` du hub →
   la convention projet prime, sauf si elle crée une faille de sécurité
5. Si une convention du projet est absente ou ambiguë → appliquer le standard
   générique du hub et le mentionner à l'utilisateur
