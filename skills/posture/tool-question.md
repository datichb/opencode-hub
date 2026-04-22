---
name: tool-question
description: Utilisation de l'outil question d'OpenCode — quand et comment poser des questions structurées à l'utilisateur via l'interface interactive plutôt que dans le texte brut.
---

# Skill — Outil `question` (OpenCode)

## Rôle

Ce skill définit quand et comment utiliser l'outil **`question`** d'OpenCode pour
interagir avec l'utilisateur de façon structurée, en présentant des choix clairs
plutôt qu'une question ouverte dans le texte.

---

## Quand utiliser `question`

Utiliser l'outil `question` (et non une question en texte libre) dans ces situations :

- **Choix entre plusieurs options** — ex. : mode de workflow, stratégie d'implémentation,
  type de branche, format de sortie
- **Confirmation d'une action à risque** — ex. : suppression, remplacement, migration
- **Collecte d'une préférence** — ex. : langue cible, niveau de détail, priorité
- **Ambiguïté dans les instructions** — ex. : deux interprétations possibles d'une demande
- **Décision qui bloque la suite** — ex. : CP-1, CP-2, CP-QA dans les workflows orchestrateur

---

## Quand NE PAS utiliser `question`

- Pour des informations factuelles déjà disponibles dans le contexte ou le codebase
- Pour des clarifications mineures qui peuvent être résolues par une hypothèse raisonnable
  (indiquer l'hypothèse dans la réponse)
- Quand la réponse n'influence pas le résultat final

---

## Structure d'une question

Chaque appel à `question` doit respecter ces principes :

- **`header`** — label court (max 30 caractères), identifie le sujet en un coup d'œil
- **`question`** — formulation complète et sans ambiguïté de ce qui est demandé
- **`options`** — liste de 2 à 5 choix, chacun avec :
  - `label` — 1 à 5 mots, concis
  - `description` — explication courte de ce que ce choix implique
- Mettre l'option recommandée **en premier** avec `(Recommandé)` dans le label si applicable
- Ne pas inclure d'option "Autre" — l'outil ajoute automatiquement "Saisir une réponse"

---

## Exemples d'usage

### Choix de mode

```
question({
  header: "Mode de workflow",
  question: "Quel mode de workflow pour cette session ?",
  options: [
    { label: "Manuel (Recommandé)", description: "Chaque étape attend ta confirmation" },
    { label: "Semi-auto", description: "Démarre et enchaîne automatiquement, QA et review restent manuels" },
    { label: "Auto", description: "Workflow entièrement automatique sauf les décisions de commit" }
  ]
})
```

### Confirmation d'action risquée

```
question({
  header: "Suppression fichier",
  question: "Le fichier src/legacy/old-service.ts sera supprimé. Confirmes-tu ?",
  options: [
    { label: "Oui, supprimer", description: "Le fichier sera supprimé — irréversible sans git restore" },
    { label: "Non, conserver", description: "La suppression est annulée, le fichier reste en place" }
  ]
})
```

### Choix de branche

```
question({
  header: "Branche dédiée",
  question: "Créer une branche dédiée pour ce ticket ?",
  options: [
    { label: "Oui (Recommandé)", description: "Crée feat/bd-42-mon-ticket avant de démarrer" },
    { label: "Non", description: "Rester sur la branche courante" }
  ]
})
```

---

## Questions posées en tant que sous-agent

Quand tu es invoqué par un agent parent (orchestrateur, orchestrator-dev, etc.) et que tu dois
poser une question à l'utilisateur, **le champ `question` doit toujours commencer par un bloc
de contexte** sur une ligne dédiée, afin que l'utilisateur comprenne sans avoir à consulter la
session enfant.

### Format obligatoire

```
[<Nom de l'agent> — <Phase ou étape en cours> | <Feature ou ticket concerné>]
<Question proprement dite>
```

### Exemple

```
question({
  header: "Validation du contexte",
  question: "[Planner — Phase 0 : Validation du contexte | Feature : authentification JWT]\nCe contexte correspond-il à votre projet ? Des corrections avant de continuer ?",
  options: [
    { label: "Oui — continuer (Recommandé)", description: "Lancer la phase de discovery" },
    { label: "Corrections à apporter", description: "Préciser ou corriger le contexte avant de continuer" }
  ]
})
```

### Règle

✅ Toujours inclure le bloc de contexte quand tu es invoqué en tant que sous-agent
✅ Le bloc de contexte doit identifier : qui tu es, quelle phase est en cours, la feature ou le ticket concerné
❌ Ne pas omettre le contexte même pour une question courte — l'utilisateur n'a pas accès à ta session enfant sans naviguer manuellement

---

## Règles

✅ Poser plusieurs questions dans un seul appel quand elles sont liées et indépendantes
✅ Utiliser `multiple: true` quand l'utilisateur peut choisir plusieurs options
❌ Ne jamais poser une question déjà répondue dans la session
❌ Ne jamais reformuler la même question deux fois sans nouvelle information
