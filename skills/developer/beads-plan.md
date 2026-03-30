---
name: beads-plan
description: Guide pour lire, créer et organiser les tickets Beads (bd) — lecture, statuts, labels système, création de tickets/epics, dépendances, relations, liens externes. Référence complète dans docs/reference/beads-model.md.
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
bd list -s open --json
```

**Lister les tickets ouverts avec un label spécifique :**
```bash
bd list -s open --label <label> --json
```

**Tickets prêts à travailler (non bloqués, blocker-aware) :**
```bash
bd ready --json
```

**Tickets prêts avec un label spécifique :**
```bash
bd ready --label <label> --json
```

> Préférer `bd ready` à `bd list --ready` — sémantique blocker-aware plus complète.

**Voir le détail complet d'un ticket :**
```bash
bd show <ID>
```

**Voir les tickets enfants d'un epic :**
```bash
bd children <EPIC_ID>
```

---

## Statuts

6 statuts disponibles. Seuls `closed` et `cancelled` sont terminaux (pas de réouverture).

| Statut | Commande |
|--------|----------|
| `open` | État par défaut à la création |
| `in_progress` | `bd update <ID> --claim` (atomique : assigne + `in_progress`) |
| `review` | `bd update <ID> -s review` |
| `blocked` | `bd update <ID> -s blocked` |
| `cancelled` | `bd update <ID> -s cancelled` (terminal — pas `bd close`) |
| `closed` | `bd close <ID>` (terminal) |

**Transitions courantes :**
- `open → in_progress → review → closed`
- `review → in_progress` (rejet — retour en dev)
- `in_progress → blocked → in_progress` (blocage/déblocage)
- `open → cancelled` (abandon avant prise en charge)

---

## Labels

**Connaître les labels disponibles dans ce projet :**
```bash
bd label list-all
```

**Ajouter un label à un ticket :**
```bash
bd label add <ID> <label>
# ou
bd update <ID> --add-label <label>
```

**Retirer un label :**
```bash
bd update <ID> --remove-label <label>
```

### Labels système

| Label | Usage |
|-------|-------|
| `ai-delegated` | Ticket délégué à un agent IA (posé par l'humain uniquement) |
| `needs-decision` | Bloqué par une décision humaine (choix technique, arbitrage métier) |
| `needs-clarification` | Description ou critères d'acceptance insuffisants |
| `from-diagnostic` | Créé suite à un diagnostic de bug (rapport du debugger) |
| `split-from-<ID>` | Résulte de la scission d'un ticket trop gros |

---

## Créer des tickets et epics

**Créer un ticket avec type, priorité et labels :**
```bash
bd create "Titre" -t feature -p 1 --json
bd create "Titre" -t task -p 2 -l ai-delegated --json
bd create "Titre" -t bug -p 0 -a dev-agent --json
```

**Types disponibles (5) :**
`epic`, `feature`, `task`, `bug`, `chore`

**Priorités (4) — forme numérique uniquement :**
`-p 0` (P0 critique), `-p 1` (P1 haute), `-p 2` (P2 normale, défaut), `-p 3` (P3 basse)

**Créer un epic (ticket parent) :**
```bash
bd create "Titre de l'epic" -t epic --json
```

**Créer un ticket rattaché à un epic :**
```bash
bd create "Titre du ticket" -t feature -p 1 --parent <EPIC_ID> --json
```

**Créer un ticket avec dépendance :**
```bash
bd create "Titre" -t task -p 2 --parent <EPIC_ID> --deps <DEP_ID> --json
```

**Créer un ticket issu d'une scission :**
```bash
T=$(bd create "Titre" -t task -p 2 -l split-from-bd-42 --parent <EPIC_ID> --json)
```

### Mettre à jour un ticket existant

```bash
bd update <ID> --description "Nouvelle description"
bd update <ID> --acceptance "- Critère 1\n- Critère 2"
bd update <ID> --notes "Contexte, risques, points d'attention"
bd update <ID> --design "Notes de design, maquettes"
bd update <ID> -a <assignee>
```

---

## Dépendances et relations

**Ajouter / retirer une dépendance (bloquante) :**
```bash
bd dep add <ID> <DEP_ID>
bd dep remove <ID> <DEP_ID>
```

**Visualiser les dépendances :**
```bash
bd dep list <ID>     # dépendances d'un ticket
bd dep tree          # arbre complet
bd dep cycles        # détecter les cycles
```

**Relation libre (informative, sans blocage) :**
```bash
bd dep relate <ID> <OTHER>
bd dep unrelate <ID> <OTHER>
```

**Marquer un doublon :**
```bash
bd duplicate <ID> --of <CANONICAL>
# Auto-ferme <ID>
```

**Remplacer un ticket :**
```bash
bd supersede <ID> --with <NEW>
# Auto-ferme <ID>
```

---

## Commentaires

```bash
bd comments add <ID> "Texte du commentaire"
```

Utiliser les commentaires pour tracer les décisions, blocages et échanges
sans modifier la description ou les notes du ticket.

---

## Lier un ticket à un tracker externe (Jira / GitLab)

Si le projet est configuré avec un tracker externe (Jira ou GitLab), tu peux
lier un ticket Beads à son correspondant externe via `--external-ref` :

```bash
# Lors de la création
bd create "Titre" -t feature -p 1 --external-ref jira-PROJECT-123 --json

# Sur un ticket existant
bd update <ID> --external-ref jira-PROJECT-123
bd update <ID> --external-ref gitlab-456
```

Convention de nommage :
- Jira : `jira-<PROJET>-<NUMERO>` (ex : `jira-MYAPP-42`)
- GitLab : `gitlab-<NUMERO>` (ex : `gitlab-17`)

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
bd label add <ID> ai-delegated

# Reprendre la main sur un ticket
bd update <ID> --remove-label ai-delegated
```
