---
name: onboarder-handoff-format
description: Source de vérité pour le format de retour de l'onboarder vers l'orchestrator. Définit le bloc structuré à produire quand l'onboarder termine son exploration et est invoqué depuis l'orchestrator (Mode C). Injecté dans l'onboarder et dans l'orchestrator pour garantir que producteur et consommateur partagent le même contrat.
---

# Skill — Format de handoff onboarder → orchestrator

Ce skill est la **source de vérité** pour le format de retour de l'`onboarder` vers l'orchestrator.
Il est injecté dans l'`onboarder` et dans l'`orchestrator` — producteur et consommateur partagent le même contrat.

---

## Quand produire ce bloc

Quand tu es invoqué depuis l'`orchestrator` (Mode C — projet inconnu),
tu **dois** produire dans cet ordre :

1. **Le rapport d'onboarding complet** — présentation narrative du contexte de découverte du projet : comment les éléments ont été trouvés, ce qui a été surprenant ou notable, zones d'incertitude avec leur contexte. **Ce rapport doit être produit même si le contexte est partiel ou bloqué.** Il n'a pas à reproduire les listes structurées (stack, conventions, dette) — celles-ci sont dans le bloc structuré qui suit.
2. **Le bloc `## Retour vers orchestrator`** défini ci-dessous — résumé structuré actionnable.

En standalone (invocation directe), le rapport d'onboarding précède également ce bloc.

> **Autocontrôle obligatoire avant de produire ce bloc :**
> « Ai-je produit le rapport d'onboarding complet avant ce bloc ? Si non, le produire d'abord. »

---

## Format du bloc `## Retour vers orchestrator`

```
---

## Retour vers orchestrator

**Agent :** onboarder
**Projet :** <nom du projet>

### Stack technique
**Langages :** <liste>
**Frameworks :** <liste>
**Base de données :** <liste>
**Infrastructure :** <liste — cloud, containers, etc.>
**Outils :** <liste — CI/CD, tests, linting, etc.>
**Versions clés :** <ex : Node 20, PHP 8.2, Python 3.11, etc.>

### Contexte métier
**Domaine(s) :** <liste> (ou "Non identifié — projet générique")
**Utilisateurs cibles :** <liste> (ou "Non documentés")
**Concepts clés :** <liste des concepts métier récurrents>
**Glossaire :** <Présent dans docs/glossary.md / Absent>
**Pattern architecture :** <DDD / CQRS / Layered / MVC / Non documenté>

### Design et maquettes
**Fichiers Figma :** <X fichiers — [URLs]> (ou "Aucun fichier détecté")
**Design system :** <DSFR / Material / Custom / Aucun>
**Design tokens :** <X tokens couleur, Y typo, Z spacing / Non configurés>
<"Non applicable (projet backend)" si pas de frontend>

### Stratégie de test
**Frameworks :** <unitaires : X, E2E : Y>
**Seuil couverture :** <X% configuré / Non configuré>
**Ratio test/source :** <calculé>
**Philosophie :** <TDD / BDD / Test-after>

### Conventions identifiées
- <convention 1 — ex : nommage en camelCase pour les variables, PascalCase pour les composants>
- <convention 2 — ex : tests unitaires avec Jest, colocalisés avec le code source>
- <convention 3 — ex : branches au format feature/<ID>-<description>>
<"Conventions non déterminables sans clarification" si aucune convention claire n'a pu être détectée>

### Dette technique détectée
- 🔴 <dette critique 1 — ex : dépendances avec CVE critiques connues>
- 🟠 <dette importante 1 — ex : absence de tests sur les composants métier principaux>
- 🟡 <dette mineure 1 — ex : fichiers de configuration dupliqués>
<"Aucune dette technique identifiée" si le projet est en bon état>

### Zones d'incertitude
- <point 1 — ce que l'exploration n'a pas pu déterminer et qui pourrait impacter la feature>
- <point 2 — question à poser à l'utilisateur avant de démarrer>
<"Aucune zone d'incertitude" si le projet est bien documenté et sans ambiguïté>

### Fichiers de contexte produits
- `ONBOARDING.md` — <créé | mis à jour | non créé (raison)>
- `CONVENTIONS.md` — <créé | mis à jour | non créé (raison)>
- `docs/context/technical.md` — <créé | mis à jour | non créé (raison)>
- `docs/context/business/` — <liste des fichiers créés/mis à jour, ex : auth.md, billing.md | aucun>

### Statut
`contexte-établi` | `contexte-partiel` | `bloqué`
```

**Définitions du statut :**

| Statut | Condition |
|--------|-----------|
| `contexte-établi` | Exploration complète, fichiers produits, contexte suffisant pour démarrer la feature |
| `contexte-partiel` | Exploration réalisée mais avec des zones d'incertitude significatives — feature démarrable avec précautions |
| `bloqué` | Exploration impossible ou contexte insuffisant pour démarrer — intervention manuelle requise |

---

## Règles pour le producteur (onboarder)

- **Toujours produire le rapport d'onboarding complet** avant ce bloc — même si le contexte est `bloqué` ou `partiel`. Le rapport est obligatoire dans tous les cas. Il apporte **le contexte de découverte et les observations narratives** — pas un ré-encodage des listes structurées (stack, conventions, dette) qui sont dans le bloc.
- **Toujours produire ce bloc** à la suite du rapport, même si le statut est `bloqué`
- **Renseigner toutes les sections** — même si vides, utiliser la mention explicite correspondante
- **Ne pas inventer** de conventions ou de stack — uniquement ce qui a été effectivement observé dans la codebase
- **Signaler honnêtement les zones d'incertitude** — l'orchestrator en a besoin pour informer l'utilisateur avant de démarrer
- Ce bloc est produit **après** l'écriture des fichiers (ou après refus explicite de les écrire)

> ❌ Ne jamais produire le bloc handoff sans avoir d'abord produit le rapport d'onboarding complet.
> ❌ Ne jamais résumer le rapport — le bloc est un résumé structuré, pas un substitut.

---

## Règles pour le consommateur (orchestrator)

> Protocole de retranscription complet (séquence obligatoire, templates, checklist, exemples) → skill `posture/retranscription-coordinateur`.

**Spécificités onboarder à vérifier :**

- **Champs obligatoires** : `Stack technique`, `Contexte métier`, `Design et maquettes`, `Stratégie de test`, `Conventions identifiées`, `Dette technique détectée`, `Zones d'incertitude`, `Fichiers de contexte produits`, `Statut`. Le champ `Fichiers de contexte produits` doit mentionner ONBOARDING.md, CONVENTIONS.md, docs/context/technical.md et docs/context/business/. Si l'un est absent → demander à l'onboarder de compléter.
- **CP-onboard** : présenter `### Zones d'incertitude` à l'utilisateur pour décision, signaler les éléments 🔴 de `### Dette technique détectée`.
- **Délégation** : intégrer `### Stack technique` dans le prompt de délégation à `orchestrator-dev`.
- **Statut** : `contexte-établi` → CP-onboard normal · `contexte-partiel` → signaler les incertitudes · `bloqué` → ne pas démarrer la feature.
