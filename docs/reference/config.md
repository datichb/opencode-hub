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

---

## `opencode.json`

Fichier de configuration OpenCode à la racine d'un projet cible.
**Créé par `oc deploy opencode` seulement s'il n'existe pas encore** — conservé
tel quel s'il est déjà présent.

### Contenu généré

```json
{
  "model": "claude-sonnet-4-5"
}
```

Le modèle est lu depuis `config/hub.json` → clé `opencode.model`.

> Ce fichier **doit être commité** dans le projet cible — il configure le modèle
> utilisé par OpenCode dans ce projet.

---

## `.gitignore` du hub

Fichiers et dossiers ignorés par git dans le hub lui-même :

```gitignore
projects/projects.md        # registre local des projets
projects/paths.local.md     # chemins locaux
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
