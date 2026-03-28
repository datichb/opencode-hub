# ADR-005 — Adaptation linguistique des agents au projet cible

## Statut

Proposé — décision ouverte

## Contexte

Le hub opencode-hub est rédigé entièrement en français : agents, skills, documentation.
Cependant, les projets sur lesquels les agents sont déployés peuvent avoir des langues
de travail différentes (anglais, espagnol, etc.).

Actuellement, un agent déployé sur un projet anglophone va produire ses rapports,
ses comptes rendus et ses messages en français, ce qui crée une friction pour
les équipes non francophones.

La question est : comment permettre aux agents de s'adapter à la langue du projet
cible sans dupliquer tous les fichiers agents/skills pour chaque langue ?

## Décision

**Aucune décision prise à ce stade.** Cette ADR documente le problème identifié
et les options en cours d'évaluation.

## Options en cours d'évaluation

### Option A — Instruction de langue dans le frontmatter du projet

Ajouter une clé `language` dans `projects.md` ou dans un fichier de config projet.
L'adapter injecterait une instruction de langue en tête de chaque agent déployé :

```markdown
<!-- Instruction injectée par l'adapter -->
> Langue de travail de ce projet : anglais. Produire tous les rapports et réponses
> en anglais, quelle que soit la langue des instructions ci-dessous.
```

**Avantages** : simple, aucun fichier à dupliquer, les agents restent en français.
**Inconvénients** : fiabilité variable selon le modèle IA utilisé.

### Option B — Traduction des skills par l'adapter

Le déploiement (`oc deploy`) traduit automatiquement les fichiers skills via l'API
d'un LLM avant injection. Les agents déployés sont dans la langue du projet.

**Avantages** : les agents sont natifs dans la langue cible.
**Inconvénients** : coût API, temps de déploiement, maintenance des traductions.

### Option C — Skills multi-langues

Les skills existent en plusieurs versions linguistiques :
`skills/developer/dev-standards-universal.fr.md`, `.en.md`, etc.
L'adapter sélectionne la version selon la langue du projet.

**Avantages** : contrôle total sur le contenu de chaque version.
**Inconvénients** : multiplication des fichiers, maintenance lourde.

## Conséquences attendues de la décision

La décision impactera :
- La structure de `projects.md` (ajout d'un champ `language`)
- Le comportement des adapters (`opencode.adapter.sh`, etc.)
- Potentiellement la structure de `skills/`

## Prochaine étape

Évaluer l'Option A sur un projet réel anglophone avant de trancher.
