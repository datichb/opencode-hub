---
name: dev-standards-devops
description: Standards DevOps — Docker, CI/CD (GitHub Actions, GitLab CI), scripts shell, gestion des secrets, registries et bonnes pratiques d'infrastructure as code légère.
---

# Skill — Standards DevOps

## Rôle

Ce skill définit les bonnes pratiques pour le développement d'infrastructure,
les pipelines CI/CD et la containerisation.
Il complète `dev-standards-universal.md`.

---

## 🔒 Règles absolues

❌ Jamais de secrets, tokens ou credentials dans le code, les Dockerfiles ou les pipelines
❌ Jamais de `latest` comme tag d'image en production — toujours une version épinglée
❌ Ne jamais pousser directement sur `main`/`master` depuis un pipeline sans validation
✅ Tout changement d'infrastructure critique passe par une review humaine
✅ Les pipelines sont idempotents — relancer n'a pas d'effet de bord

---

## Docker

### Dockerfile

- Image de base épinglée à une version spécifique (`node:20.11-alpine`, pas `node:latest`)
- Multi-stage build systématique pour réduire la taille de l'image finale
  - Stage `builder` : compilation, installation des dépendances dev
  - Stage `production` : uniquement les artefacts nécessaires à l'exécution
- Ne pas tourner en `root` — créer un utilisateur dédié non-root
- `.dockerignore` exhaustif (exclure `node_modules`, `.git`, `*.log`, fichiers de dev)
- Instructions `RUN` regroupées pour minimiser les layers (`&&` avec `\`)
- `COPY` granulaire : copier d'abord les fichiers de dépendances, puis le code source

```dockerfile
# ✅ Multi-stage, non-root, version épinglée
FROM node:20.11-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --frozen-lockfile
COPY . .
RUN npm run build

FROM node:20.11-alpine AS production
WORKDIR /app
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=builder --chown=appuser:appgroup /app/dist ./dist
COPY --from=builder --chown=appuser:appgroup /app/node_modules ./node_modules
USER appuser
EXPOSE 3000
CMD ["node", "dist/main.js"]
```

### Docker Compose

- Un fichier `docker-compose.yml` pour le développement local
- Un `docker-compose.override.yml` pour les surcharges locales (non versionné)
- Les services ont des `healthcheck` définis
- Les volumes de données sont nommés (pas de chemins absolus)
- Les réseaux sont explicitement définis (pas de reliance sur le réseau `default`)

```yaml
services:
  app:
    build: .
    depends_on:
      db:
        condition: service_healthy
    environment:
      DATABASE_URL: ${DATABASE_URL}  # injecté depuis .env
    networks:
      - backend

  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - backend

networks:
  backend:
    driver: bridge
```

---

## GitHub Actions

### Structure des workflows

```
.github/
└── workflows/
    ├── ci.yml          ← Lint, tests, build — déclenché sur chaque PR
    ├── cd.yml          ← Déploiement — déclenché sur merge dans main
    └── release.yml     ← Publication de release / package
```

### Bonnes pratiques

- Épingler les actions à un SHA de commit (pas `@main` ni `@v3` seul)
  - `uses: actions/checkout@v4` → acceptable pour les actions officielles maintenues
  - `uses: un-tiers/action@abc1234` → SHA obligatoire pour les actions tierces
- Utiliser `permissions` au niveau minimal requis par le job
- Les secrets sont injectés via `secrets.*` ou `vars.*` — jamais en dur
- Cacher les dépendances (`actions/cache`) pour réduire les temps de build
- Les jobs indépendants tournent en parallèle (`needs` uniquement si dépendance réelle)
- Utiliser `concurrency` pour annuler les runs obsolètes sur une même branche

```yaml
name: CI

on:
  pull_request:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
      - run: npm ci
      - run: npm run lint

  test:
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
      - run: npm ci
      - run: npm test -- --coverage
```

### Sécurité des pipelines

- Ne jamais afficher de secrets dans les logs (`echo $SECRET` interdit)
- `pull_request_target` n'est utilisé que si absolument nécessaire (risque d'injection)
- Les workflows déclenchés par des forks n'ont pas accès aux secrets par défaut — ne pas contourner
- Scanner les images Docker dans le pipeline (Trivy, Grype)

---

## GitLab CI

### Structure `.gitlab-ci.yml`

- Définir les stages explicitement (`stages: [lint, test, build, deploy]`)
- Utiliser des `extends` ou des `!reference` pour factoriser les jobs communs
- Les variables sensibles sont dans les CI/CD Variables (masked + protected)
- Utiliser `rules` plutôt que `only`/`except` (déprécié)
- Les déploiements en production ont `when: manual` ou un approval obligatoire

```yaml
stages:
  - lint
  - test
  - build
  - deploy

variables:
  DOCKER_DRIVER: overlay2

.node_template: &node_template
  image: node:20-alpine
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/

lint:
  <<: *node_template
  stage: lint
  script:
    - npm ci
    - npm run lint

test:
  <<: *node_template
  stage: test
  script:
    - npm ci
    - npm test
  coverage: '/Lines\s*:\s*(\d+\.?\d*)%/'

deploy:production:
  stage: deploy
  when: manual
  only:
    - main
  script:
    - echo "Déploiement en production"
```

---

## Scripts shell

- Toujours commencer par `#!/usr/bin/env bash` et `set -euo pipefail`
- Pas de `local` en dehors d'une fonction bash
- Toutes les variables sont entre guillemets : `"$variable"` (pas `$variable`)
- Pas de parsing de `ls` — utiliser des globs ou `find`
- Les fonctions ont des noms en `snake_case` et sont documentées
- Les scripts ont un message d'usage (`usage()`) et gèrent `--help`
- Pas de chemins absolus codés en dur — utiliser `$(dirname "$0")` pour les chemins relatifs au script

```bash
#!/usr/bin/env bash
set -euo pipefail

# Description : déploie l'application sur l'environnement cible
# Usage : ./deploy.sh <environment>

usage() {
  echo "Usage: $0 <environment>"
  echo "  environment : staging | production"
  exit 1
}

main() {
  local environment="${1:-}"

  if [[ -z "$environment" ]]; then
    usage
  fi

  case "$environment" in
    staging|production)
      echo "Déploiement sur $environment..."
      ;;
    *)
      echo "Environnement inconnu : $environment" >&2
      usage
      ;;
  esac
}

main "$@"
```

---

## Gestion des secrets

- Les secrets ne sont jamais dans le code source ni dans les fichiers versionnés
- `.env` est dans `.gitignore` — `.env.example` est versionné avec des valeurs fictives
- En production : gestionnaire de secrets (AWS Secrets Manager, HashiCorp Vault, Doppler, etc.)
- En CI/CD : variables d'environnement injectées par le système (GitHub Secrets, GitLab Variables)
- Rotation régulière des secrets critiques (tokens, clés API)
- Principe du moindre privilège : un secret = un service, une portée minimale

---

## Registries d'images

- Taguer les images avec : le SHA de commit + un tag de version sémantique si release
  - `myapp:abc1234` (toujours)
  - `myapp:v1.2.3` (sur release)
  - `myapp:latest` (uniquement en développement, jamais en production)
- Scanner les images avant push (Trivy, Snyk Container)
- Nettoyer régulièrement les images non utilisées (politique de rétention)
- Utiliser un registry privé pour les images propriétaires

---

## Observabilité

- Chaque service expose un endpoint de healthcheck (`/health` ou `/_health`)
- Les logs sont structurés (JSON) avec les champs : `level`, `timestamp`, `message`, `service`, `trace_id`
- Les métriques applicatives sont exposées (Prometheus `/metrics`)
- Les alertes sont définies en code (Alertmanager, PagerDuty rules)

---

## Infrastructure as Code légère

- Tout changement d'infrastructure est versionné et reviewé (même les petits scripts)
- Les environnements sont reproductibles : dev = staging ≈ production (différences documentées)
- Les configurations d'environnement sont séparées du code d'infrastructure
- Documenter les prérequis et la procédure de bootstrap dans le README

---

## Ce que tu ne fais PAS

- Modifier directement les configurations de production sans pipeline validé
- Utiliser `--force` sur des opérations git ou des déploiements sans confirmation explicite
- Créer des credentials avec des droits plus larges que nécessaire
- Ignorer les échecs de pipeline "pour aller plus vite"
