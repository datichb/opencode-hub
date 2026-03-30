# Référence de configuration

---

## `config/hub.json`

Configuration globale du hub. Créé par `oc install` et modifiable manuellement.

### Structure complète

```json
{
  "version": "2.0.0",
  "default_target": "opencode",
  "active_targets": ["opencode"],
  "opencode": {
    "model": "claude-sonnet-4-5"
  },
  "vscode": {
    "global_skills": [
      "developer/dev-standards-universal",
      "developer/dev-standards-frontend-a11y"
    ]
  }
}
```

### Référence des clés

| Clé | Type | Défaut | Description |
|-----|------|--------|-------------|
| `version` | string | — | Version du hub (lue par `oc version`) |
| `default_target` | string | `"opencode"` | Cible utilisée par `oc start` |
| `active_targets` | array | `["opencode"]` | Cibles déployées par `oc deploy all`, `oc sync` et mises à jour par `oc update` |
| `opencode.model` | string | — | Modèle IA injecté dans `opencode.json` des projets déployés |
| `vscode.global_skills` | array | `[]` | Skills injectés dans `copilot-instructions.md` (partagés par tous les agents VS Code) |

### Cibles disponibles

| Valeur | Outil cible |
|--------|-------------|
| `opencode` | OpenCode (`opencode run`) |
| `claude-code` | Claude Code |
| `vscode` | VS Code / GitHub Copilot |

### Exemple minimal (OpenCode uniquement)

```json
{
  "version": "2.0.0",
  "default_target": "opencode",
  "active_targets": ["opencode"],
  "opencode": {
    "model": "claude-sonnet-4-5"
  }
}
```

### Exemple multi-cibles

```json
{
  "version": "2.0.0",
  "default_target": "opencode",
  "active_targets": ["opencode", "claude-code", "vscode"],
  "opencode": {
    "model": "claude-sonnet-4-5"
  },
  "vscode": {
    "global_skills": [
      "developer/dev-standards-universal",
      "developer/dev-standards-frontend-a11y"
    ]
  }
}
```

---

## `projects/projects.md`

Registre local des projets. **Ignoré par git** — chaque développeur maintient
le sien. Créé automatiquement depuis `projects/projects.example.md` au premier
`oc install` ou `oc init`.

### Format

```markdown
## PROJECT_ID
- Nom : Nom lisible du projet
- Stack : Stack technique (ex: Vue 3 + Laravel)
- Board Beads : Identifiant du board Beads
- Tracker : jira | gitlab | none
- Labels : label1, label2, label3
- Langue : english        # optionnel — si absent : agents en français par défaut
```

### Exemple

```markdown
## MON-APP
- Nom : Mon Application
- Stack : Vue 3 + Laravel 10
- Board Beads : MON-APP
- Tracker : jira
- Labels : feature, fix, front, back

## API-GATEWAY
- Nom : API Gateway
- Stack : Node.js + Fastify
- Board Beads : API-GATEWAY
- Tracker : none
- Labels : feature, fix, api
- Langue : english
```

### Règles

- `PROJECT_ID` : lettres, chiffres, `-` et `_` uniquement — pas d'espaces ni de slashes
- `Tracker` : `jira`, `gitlab` ou `none`
- `Langue` : optionnel — valeur libre (ex: `english`, `spanish`) — si absent, les agents s'expriment en français
- Ce fichier est **local** — ne jamais le committer

---

## `projects/projects.example.md`

Template versionné pour `projects.md`. Copié automatiquement en `projects/projects.md`
si ce fichier est absent.

Modifier ce template pour définir la structure de projet par défaut de votre équipe.

---

## `projects/paths.local.md`

Associe chaque `PROJECT_ID` à un chemin local sur la machine du développeur.
**Ignoré par git.**

### Format

```
PROJECT_ID=/chemin/absolu/vers/le/projet
```

### Exemple

```
MON-APP=~/workspace/mon-app
API-GATEWAY=/home/user/projets/api-gateway
AUTRE-APP=~/dev/autre-app
```

### Règles

- Un `PROJECT_ID` par ligne
- Chemins absolus ou avec `~` (expansé par le shell)
- Ne pas committer ce fichier — chaque développeur a ses propres chemins locaux

## `projects/api-keys.local.md`

Stocke les clés API et modèles configurés par projet via `oc config`.
**Ignoré par git** — ne jamais committer ce fichier.

### Format

```ini
[PROJECT_ID]
model=claude-opus-4-5
provider=anthropic
api_key=sk-ant-...

[AUTRE-PROJET]
model=claude-sonnet-4-5
provider=litellm
api_key=sk-bRf...
base_url=https://api.mammouth.ai/v1
```

### Clés disponibles par section

| Clé | Requis | Description |
|-----|--------|-------------|
| `model` | oui | Modèle IA (ex: `claude-opus-4-5`, `claude-haiku-4-5`) |
| `provider` | oui | `anthropic` ou `litellm` |
| `api_key` | oui | Clé API — jamais affichée en clair |
| `base_url` | non | URL de base (litellm uniquement, ex: `https://api.mammouth.ai/v1`) |

### Providers supportés

| Provider | Usage | `base_url` requis |
|----------|-------|-------------------|
| `anthropic` | Clé Anthropic directe | non |
| `litellm` | Proxy compatible OpenAI (mammouth.ai, etc.) | oui (recommandé) |

### Effets lors du déploiement

Lors d'un `oc deploy opencode <PROJECT_ID>`, si une entrée existe pour le projet :

- `opencode.json` est régénéré avec le bloc `provider` complet
- `opencode.json` est ajouté au `.gitignore` du projet cible (contient la clé API)
- Le fichier est créé avec les permissions `600`

Pour Claude Code, la clé est injectée comme `ANTHROPIC_API_KEY` au moment du `oc start`.

---

## `oc config` — commande CLI

Gère les entrées de `projects/api-keys.local.md`.

### Sous-commandes

```
oc config set <PROJECT_ID> [options]   Créer ou mettre à jour une configuration
oc config get <PROJECT_ID>             Afficher la configuration (clé masquée)
oc config list                         Lister toutes les configurations
oc config unset <PROJECT_ID>           Supprimer une configuration
```

### Options de `oc config set`

| Option | Description |
|--------|-------------|
| `--model <model>` | Modèle IA |
| `--provider <provider>` | `anthropic` ou `litellm` |
| `--api-key <key>` | Clé API (si omis : saisie masquée interactive) |
| `--base-url <url>` | Base URL (litellm uniquement) |

Si appelé sans flags, le flux est interactif avec les valeurs actuelles comme défauts.

### Exemple

```sh
# Flux interactif
./oc.sh config set MON-PROJET

# En ligne de commande (hors CI : préférer le flux interactif pour la clé)
./oc.sh config set MON-PROJET --model claude-opus-4-5 --provider anthropic

# Vérifier
./oc.sh config get MON-PROJET

# Supprimer
./oc.sh config unset MON-PROJET
```

---

## `opencode.json`

Fichier de configuration OpenCode à la racine d'un projet cible.
Créé par `oc deploy opencode` — **régénéré à chaque déploiement si une clé API est configurée**
pour le projet, conservé tel quel sinon.

### Contenu sans clé API

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "claude-sonnet-4-5"
}
```

### Contenu avec clé Anthropic

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "claude-opus-4-5",
  "provider": {
    "anthropic": {
      "apiKey": "sk-ant-..."
    }
  }
}
```

### Contenu avec litellm / proxy compatible OpenAI

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "claude-sonnet-4-5",
  "provider": {
    "litellm": {
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "apiKey": "sk-bRf...",
        "baseURL": "https://api.mammouth.ai/v1"
      }
    }
  }
}
```

Le modèle est résolu par priorité :
1. `projects/api-keys.local.md` → clé `model` du projet (si `PROJECT_ID` défini)
2. Variable d'env `$OPENCODE_MODEL`
3. `config/hub.json` → clé `opencode.model`
4. Fallback : `claude-sonnet-4-5`

> Si une clé API est injectée, ce fichier **ne doit pas être commité** dans le projet cible
> (ajouté automatiquement au `.gitignore` du projet par `oc deploy`).
> Sans clé API, le fichier **peut être commité**.

---

## `.gitignore` du hub

Fichiers et dossiers ignorés par git dans le hub lui-même :

```gitignore
projects/projects.md        # registre local des projets
projects/paths.local.md     # chemins locaux
projects/api-keys.local.md  # clés API par projet
.opencode/node_modules/     # dépendances OpenCode
.opencode/bun.lock
.opencode/package.json
skills/external/            # skills téléchargés via oc skills add
```

---

## Variables d'environnement

Le hub ne définit pas de variables d'environnement obligatoires.
Les credentials pour les trackers (Jira, GitLab) sont stockés localement
par `bd config set` — jamais dans des fichiers versionnés.
