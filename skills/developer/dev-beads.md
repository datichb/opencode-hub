---
name: dev-beads
description: Guide pour interagir avec Beads (bd) — lire, clamer, implémenter et clore les tickets depuis l'agent developer.
---

## 🎯 Interaction avec Beads

`bd` est le CLI de gestion de tickets. Il utilise l'**auto-discovery** : il trouve
automatiquement la base `.beads/` dans le répertoire courant ou ses parents.
Tu dois toujours être dans le répertoire du projet pour que les commandes
ciblent le bon board.

---

## 📋 Lire les tickets disponibles

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

**Connaître les labels disponibles dans ce projet :**
```bash
bd label list-all
```

---

## ✋ Clamer un ticket

Avant de commencer à implémenter, clame le ticket pour signaler que tu travailles dessus.
`--claim` est atomique : il échoue si un autre acteur a déjà réclamé le ticket.

```bash
bd update <ID> --claim
```

Cette commande met le statut à `in_progress` et t'assigne le ticket en une seule opération.

---

## 🏷️ Gérer les labels

**Ajouter un label à un ticket :**
```bash
bd update <ID> --add-label <label>
```

**Retirer un label :**
```bash
bd update <ID> --remove-label <label>
```

---

## ✅ Clore un ticket

Après implémentation et validation :

```bash
bd close <ID> --suggest-next
```

`--suggest-next` affiche les tickets qui viennent d'être débloqués par cette clôture,
ce qui permet de choisir la prochaine tâche sans relancer `bd list`.

**Clore avec une raison :**
```bash
bd close <ID> --reason "Implémenté dans le commit abc123"
```

---

## 🔄 Workflow obligatoire

```
1. bd list --ready --json          → identifier les tickets disponibles
2. bd show <ID>                    → lire le détail (description, acceptance, notes)
3. bd update <ID> --claim          → clamer avant de commencer
4. [implémenter]
5. bd close <ID> --suggest-next    → clore et voir le ticket suivant
```

**⚠️ Règles :**
- Toujours `bd show <ID>` avant d'implémenter — ne jamais supposer le contenu d'un ticket
- Toujours clamer avant d'implémenter — évite les conflits si plusieurs agents tournent
- Toujours clore explicitement — ne pas laisser de tickets `in_progress` orphelins
- Ne pas modifier le titre ou la description d'un ticket sans y être invité
- Si un ticket est bloqué par une dépendance, utiliser `bd list --ready` pour en trouver un autre
