---
name: debugger-handoff-format
description: Source de vérité pour le format de retour du debugger vers l'orchestrator. Définit le bloc structuré à produire quand le debugger termine son diagnostic et est invoqué depuis l'orchestrator (Mode D). Injecté dans le debugger et dans l'orchestrator pour garantir que producteur et consommateur partagent le même contrat.
---

# Skill — Format de handoff debugger → orchestrator

Ce skill est la **source de vérité** pour le format de retour du `debugger` vers l'orchestrator.
Il est injecté dans le `debugger` et dans l'`orchestrator` — producteur et consommateur partagent le même contrat.

---

## Quand produire ce bloc

Quand tu es invoqué depuis l'`orchestrator` (Mode D — bug signalé par l'utilisateur),
tu **dois** produire dans cet ordre :

1. **Le rapport de diagnostic complet** — analyse narrative du symptôme observé (comportement attendu vs. réel, conditions de déclenchement, fréquence), périmètre analysé (artefacts disponibles et manquants), hypothèses explorées avec les **preuves et éléments qui les étayent ou les écartent**, localisation probable (fichier:ligne), informations manquantes pour confirmer certaines hypothèses. **Ce rapport doit être produit même si le diagnostic est partiel ou le bug non reproductible.** Il n'a pas à répéter la cause racine structurée ni les listes d'hypothèses — celles-ci sont dans le bloc structuré qui suit.
2. **Le bloc `## Retour vers orchestrator`** défini ci-dessous — résumé structuré actionnable.

En standalone (invocation directe), le rapport de diagnostic précède également ce bloc.

> **Autocontrôle obligatoire avant de produire ce bloc :**
> « Ai-je produit le rapport de diagnostic complet avant ce bloc ? Si non, le produire d'abord. »

---

## Format du bloc `## Retour vers orchestrator`

```
---

## Retour vers orchestrator

**Agent :** debugger
**Problème :** <description courte du bug tel que signalé — verbatim si possible>

### Cause racine
**Hypothèse retenue :** <cause racine identifiée — formulée en hypothèse si incertitude>
**Niveau de certitude :** <confirmé | probable | incertain>
**Chaîne causale :**
1. <étape 1 — événement déclencheur>
2. <étape 2 — propagation>
3. <étape 3 — symptôme observable>
<"Cause racine non déterminée" si le diagnostic n'a pas pu identifier la cause>

### Hypothèses explorées
- `<hypothèse 1>` : **écartée** — <raison>
- `<hypothèse 2>` : **confirmée** — <raison>
- `<hypothèse 3>` : **insuffisamment documentée** — <ce qui manque pour la confirmer ou l'écarter>
<"Aucune hypothèse alternative explorée" si la cause était évidente>

### Impact et régressions potentielles
- <composant ou feature impacté 1 — ex : authentification compromise si le bug est en prod>
- <régression possible 1 — ex : tout le flux de paiement est potentiellement affecté>
- <utilisateurs touchés si estimable — ex : tous les utilisateurs sur mobile>
<"Impact limité au composant isolé, aucune régression identifiée" si l'impact est contenu>

### Tickets de correction créés

| ID | Titre | Priorité | Labels |
|----|-------|----------|--------|
| bd-XX | <titre du ticket de correction> | P<X> | <labels> |

<"Aucun ticket créé — refus de l'utilisateur" si l'utilisateur a répondu Non à la création>
<"Aucun ticket créé — cause non déterminée, correction impossible à planifier" si diagnostic incomplet>

### Actions d'urgence si bug en prod
<steps immédiats à réaliser si le bug est actif en production>
<ex : "Désactiver le feature flag X", "Rollback vers la version Y", "Bloquer les requêtes vers /endpoint">
<"N/A — bug non critique en production" si le bug n'est pas en prod ou n'est pas urgent>

### Statut
`diagnostiqué` | `partiellement-diagnostiqué` | `non-reproductible`
```

**Définitions du statut :**

| Statut | Condition |
|--------|-----------|
| `diagnostiqué` | Cause racine identifiée avec certitude suffisante, ticket créé |
| `partiellement-diagnostiqué` | Hypothèse probable mais sans certitude — ticket créé avec les informations disponibles |
| `non-reproductible` | Bug non reproductible depuis la codebase — artefacts insuffisants ou bug intermittent |

---

## Règles pour le producteur (debugger)

- **Toujours produire le rapport de diagnostic complet** avant ce bloc — même si le diagnostic est `non-reproductible`. Le rapport est obligatoire dans tous les cas. Il apporte **les preuves, l'analyse et le raisonnement** (symptôme détaillé, éléments qui étayent ou écartent chaque hypothèse) — pas un ré-encodage des champs structurés du bloc.
- **Toujours produire ce bloc** à la suite du rapport, même si le statut est `non-reproductible`
- **Ne jamais affirmer une cause racine sans éléments probants** — utiliser "confirmé / probable / incertain" dans `Niveau de certitude`
- **Renseigner toutes les sections** — même si vides, utiliser la mention explicite correspondante
- **Signaler honnêtement les `### Hypothèses explorées`** — y compris celles insuffisamment documentées
- **Signaler l'impact honnêtement** — ne pas minimiser si des régressions sont possibles
- Ce bloc est produit **après** la création du ticket (ou après refus explicite de l'utilisateur)

> ❌ Ne jamais produire le bloc handoff sans avoir d'abord produit le rapport de diagnostic complet.
> ❌ Ne jamais résumer le rapport — le bloc est un résumé structuré, pas un substitut.

---

## Règles pour le consommateur (orchestrator)

> Protocole de retranscription complet (séquence obligatoire, templates, checklist, exemples) → skill `posture/retranscription-coordinateur`.

**Spécificités debugger à vérifier :**

- **Champs obligatoires** : `Cause racine`, `Impact et régressions potentielles`, `Tickets de correction créés`, `Statut`. Si l'un est absent → demander au debugger de compléter avant de continuer.
- **Priorité absolue** : présenter `### Actions d'urgence si bug en prod` en premier si renseignées — elles priment sur toute autre décision.
- **Suite** : si des tickets ont été créés → proposer à l'utilisateur de les intégrer dans le workflow (Mode A ou B). Si aucun ticket (cause non déterminée) → informer et proposer les options.
- **Statut** : `diagnostiqué` → cause établie · `partiellement-diagnostiqué` → signaler l'incertitude · `non-reproductible` → ne pas créer de ticket sans plus d'information.
- **Transmission** : ne jamais passer les tickets créés directement à `orchestrator-dev` sans les présenter à l'utilisateur d'abord.
