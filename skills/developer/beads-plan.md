---
name: beads-plan
description: Guide pour lire, créer et organiser les tickets Beads (bd) — lecture, labels, création de tickets/epics, liens externes. Pour planificateurs et exécuteurs.
---

## Interaction avec Beads

`bd` est le CLI de gestion de tickets. Il utilise l'**auto-discovery** : il trouve
automatiquement la base `.beads/` dans le répertoire courant ou ses parents.
Tu dois toujours être dans le répertoire du projet pour que les commandes
ciblent le bon board.

---

## Lire les tickets

**Lister les tickets ouverts :**
```bash
bd list --status open --json
```

**Lister les tickets ouverts avec un label spécifique :**
```bash
bd list --status open --label <label> --json
```

**Lister les tickets prêts à travailler (non bloqués) :**
```bash
bd list --ready --json
```

**Voir le détail complet d'un ticket :**
```bash
bd show <ID>
```

**Voir les tickets enfants d'un epic :**
```bash
bd children <EPIC_ID>
```

---

## Labels

**Connaître les labels disponibles dans ce projet :**
```bash
bd label list-all
```

**Ajouter un label à un ticket :**
```bash
bd update <ID> --add-label <label>
```

**Retirer un label :**
```bash
bd update <ID> --remove-label <label>
```

---

## Créer des tickets et epics

**Créer un ticket simple :**
```bash
bd create "Titre du ticket"
```

**Créer un ticket avec description et priorité :**
```bash
bd create "Titre" --description "Description détaillée" --priority high
```

**Créer un epic (ticket parent) :**
```bash
bd create "Titre de l'epic" --type epic
```

**Créer un ticket rattaché à un epic :**
```bash
bd create "Titre du ticket" --parent <EPIC_ID>
```

**Mettre à jour un ticket existant :**
```bash
bd update <ID> --description "Nouvelle description"
bd update <ID> --priority medium
bd update <ID> --deps <AUTRE_ID>
```

---

## Lier un ticket à un tracker externe (Jira / GitLab)

Si le projet est configuré avec un tracker externe (Jira ou GitLab), tu peux
lier un ticket Beads à son correspondant externe via `--external-ref` :

```bash
# Lors de la création
bd create "Titre" --external-ref jira-PROJECT-123

# Sur un ticket existant
bd update <ID> --external-ref jira-PROJECT-123
bd update <ID> --external-ref gitlab-456
```

Le format de référence externe est libre mais par convention :
- Jira : `jira-<PROJET>-<NUMERO>` (ex: `jira-MYAPP-42`)
- GitLab : `gitlab-<NUMERO>` (ex: `gitlab-17`)

> **Note :** La synchronisation bidirectionnelle est gérée par l'humain via
> `oc beads sync <PROJECT_ID>` — tu ne lances pas cette commande toi-même.

---

## Label `ai-delegated`

Seuls les tickets portant le label **`ai-delegated`** sont délégués aux agents.
**L'humain décide quels tickets déléguer.**

**Tu ne dois JAMAIS :**
- Ajouter toi-même le label `ai-delegated` sur un ticket sans accord explicite
  de l'utilisateur dans la conversation

**L'humain gère la délégation :**
```bash
# Déléguer un ticket à un agent
bd update <ID> --add-label ai-delegated

# Reprendre la main sur un ticket
bd update <ID> --remove-label ai-delegated
```
