# Résolution du modèle par agent

---

## Vue d'ensemble

Chaque agent peut recevoir un modèle IA spécifique via une cascade de résolution à 7 niveaux.
Le premier niveau qui retourne une valeur gagne.

---

## Cascade de résolution (7 niveaux)

Pour un agent `X` de famille `F` dans un projet `P` :

| Priorité | Source | Clé |
|----------|--------|-----|
| 1 | Projet — agent spécifique | `api-keys.local.md` → `agent_models.agents.X=...` |
| 2 | Projet — famille | `api-keys.local.md` → `agent_models.families.F=...` |
| 3 | Projet — modèle global | `api-keys.local.md` → `model=...` |
| 4 | Hub — agent spécifique | `config/hub.json` → `.agent_models.agents.X` |
| 5 | Hub — famille | `config/hub.json` → `.agent_models.families.F` |
| 6 | Hub — modèle global | `config/hub.json` → `.opencode.model` |
| 7 | Fallback hardcodé | `claude-sonnet-4-5` |

**Exemple :** si le projet définit un modèle pour la famille `planning` (niveau 2) et que le hub définit un modèle pour l'agent `orchestrator` (niveau 4), c'est le niveau 2 qui l'emporte car il est prioritaire.

> **Note — préfixes provider :** les préfixes provider (ex. `anthropic/`) sont optionnels dans la cascade de résolution. Le fallback hardcodé (niveau 7) n'en inclut pas (`claude-sonnet-4-5`), tandis que les valeurs frontmatter ou de configuration peuvent en inclure (ex. `anthropic/claude-opus-4`). Les deux formes sont acceptées.

> **Note — `default_provider.model` :** le champ `default_provider.model` de `hub.json` n'est PAS utilisé dans cette cascade. Il sert uniquement à la configuration du provider OpenCode, pas à la résolution de modèle par agent.

---

## Plancher (clamp) via frontmatter

Les agents peuvent déclarer un modèle minimum via le champ `model:` dans leur frontmatter :

```yaml
---
id: orchestrator
model: anthropic/claude-opus-4
---
```

Après résolution de la cascade, si le modèle résolu est **inférieur** au plancher déclaré,
le plancher est appliqué et un warning est émis dans les logs.

### Hiérarchie des modèles (pour le clamp)

```
claude-opus-4 > claude-sonnet-4-5 > claude-haiku-4-5
```

> **Note :** cette liste est non exhaustive. Les modèles non listés sont considérés au rang le plus bas (rang 0).

### Agents avec plancher

| Agent | Plancher |
|-------|----------|
| `orchestrator` | `anthropic/claude-opus-4` |
| `orchestrator-dev` | `anthropic/claude-opus-4` |
| `reviewer` | `anthropic/claude-opus-4` |
| `planner` | `anthropic/claude-opus-4` |

---

## Famille d'un agent

La famille est déduite du sous-dossier parent dans `agents/` :

- `agents/planning/orchestrator.md` → famille `planning`
- `agents/developer/developer-frontend.md` → famille `developer`
- `agents/quality/reviewer.md` → famille `quality`

---

## Configuration via CLI

```bash
# Niveau hub
oc config set --family-model planning=claude-opus-4
oc config set --agent-model debugger=claude-sonnet-4-5

# Niveau projet
oc config set MY-APP --family-model planning=claude-opus-4
oc config set MY-APP --agent-model reviewer=claude-sonnet-4-5
```

---

## Règle d'injection dans opencode.json

- Si le modèle résolu == modèle global du projet → **pas d'injection** (l'agent utilise le modèle par défaut)
- Si le modèle résolu ≠ modèle global → injection de `"model": "<valeur>"` dans l'entrée de l'agent
