# Vue d'ensemble de l'architecture

## Concepts fondamentaux

### Hub

Le **hub** (`opencode-hub`) est le dépôt central qui contient les sources canoniques
de tous les agents et skills. C'est la source de vérité — on édite toujours ici,
jamais dans les projets cibles.

### Agent

Un **agent** est un fichier Markdown (`.md`) qui définit l'identité d'un rôle IA :
qui il est, ce qu'il fait, ce qu'il ne fait pas, et son workflow condensé.
Les agents sont courts (~40-80 lignes) et ne contiennent pas les protocoles détaillés.

Voir [agents.md](./agents.md) pour la référence complète.

### Skill

Un **skill** est un bloc de protocole injectable : format de rapport, checklist,
règles de comportement, exemples. Les skills sont déclarés dans le frontmatter
de l'agent (`skills: [...]`) et assemblés au déploiement.

Un skill peut être partagé entre plusieurs agents (ex: `dev-standards-universal`
est injecté dans tous les agents développeurs et dans le reviewer).

Voir [skills.md](./skills.md) pour la référence complète.
Voir [ADR-001](./adr/001-agent-skill-separation.md) pour la décision de séparation.

### Adapter

Un **adapter** est un script shell (`scripts/adapters/<cible>.adapter.sh`) qui
traduit les agents + skills du format hub vers le format attendu par un outil cible.
Trois adapters existent : `opencode`, `claude-code`, `vscode`.

### Projet cible

Un **projet cible** est un dépôt applicatif sur lequel les agents sont déployés
via `oc deploy`. Le hub connaît les projets via `projects/projects.md`.

---

## Diagramme — Flux de déploiement

```mermaid
flowchart LR
    subgraph HUB["opencode-hub (source de vérité)"]
        A[agents/*.md] --> PB[prompt-builder.sh]
        S[skills/**/*.md] --> PB
        PB --> ADP
        subgraph ADP["adapters/"]
            OC[opencode.adapter.sh]
            CC[claude-code.adapter.sh]
            VS[vscode.adapter.sh]
        end
    end

    subgraph PROJETS["Projets cibles"]
        OC -->|oc deploy opencode| P1[".opencode/agents/*.md"]
        CC -->|oc deploy claude-code| P2[".claude/agents/*.md"]
        VS -->|oc deploy vscode| P3[".vscode/prompts/*.md\n.github/copilot-instructions.md"]
    end
```

---

## Diagramme — Workflow orchestrateur

```mermaid
sequenceDiagram
    participant U as Utilisateur
    participant O as Orchestrator
    participant PL as Planner
    participant DEV as Developer-*
    participant QA as QA Engineer
    participant R as Reviewer

    U->>O: "Implémente [feature]"
    O->>PL: Délègue la planification
    PL-->>O: Tickets créés
    O->>U: [CP-0] Tickets prêts — démarrer ?

    loop Pour chaque ticket
        O->>U: [CP-1] Démarrer ticket #XX ?
        O->>DEV: Délègue l'implémentation
        DEV-->>O: Implémentation terminée
        O->>U: [CP-QA] Passer par le QA ? (optionnel)
        opt QA activé
            O->>QA: Délègue la vérification de couverture
            QA-->>O: Tests écrits + rapport couverture
        end
        O->>R: Review automatique
        R-->>O: Rapport de review
        O->>U: [CP-2] Merger ou corriger ?
        O->>U: [CP-3] Ticket suivant ou stop ?
    end

    O->>U: Récap global de la feature
```

---

## Diagramme — Workflow debug

```mermaid
sequenceDiagram
    participant U as Utilisateur
    participant D as Debugger
    participant B as Beads

    U->>D: Stacktrace / logs / description
    D->>D: Reproduction → Isolation → Identification → Hypothèse
    D-->>U: Rapport de diagnostic + ticket suggéré
    U->>D: [CP] Créer le ticket ?
    D->>B: bd create + bd update
    B-->>D: ID créé
    D-->>U: Ticket #XX créé
```

---

## Principes de design

### 1. Séparation identité / protocole

L'agent définit **qui** il est, le skill définit **comment** il travaille.
Cette séparation permet la réutilisation des protocoles entre agents et maintient
les fichiers agents lisibles.

→ [ADR-001](./adr/001-agent-skill-separation.md)

### 2. Spécialisation plutôt que généralisme

Les agents développeurs sont segmentés en 7 spécialisations pour que chaque agent
reçoive uniquement le contexte pertinent à son domaine.

→ [ADR-002](./adr/002-developer-segmentation.md)

### 3. Checkpoints explicites

L'orchestrateur ne fait jamais avancer le workflow automatiquement. Chaque étape
critique nécessite une confirmation explicite de l'utilisateur.

→ [ADR-003](./adr/003-orchestrator-checkpoints.md)

### 4. Séparation des responsabilités de qualité

Implémenter, tester et diagnostiquer sont trois responsabilités distinctes confiées
à trois agents différents (developer, qa-engineer, debugger).

→ [ADR-004](./adr/004-qa-debugger-separation.md)

### 5. Lecture seule pour les agents non-développeurs

Les agents auditor, reviewer et debugger n'écrivent jamais dans le projet cible.
Seuls les agents developer et qa-engineer modifient des fichiers.

---

## Structure des fichiers

```
opencode-hub/
├── agents/          ← Sources canoniques des agents (éditer ici)
├── skills/          ← Protocoles et standards injectables
├── scripts/
│   ├── adapters/    ← Traduction hub → format outil cible
│   ├── lib/         ← Helpers partagés (prompt-builder, adapter-manager)
│   └── cmd-*.sh     ← Implémentation des commandes oc
├── config/
│   └── hub.json     ← Configuration globale du hub
├── projects/
│   ├── projects.md       ← Registre des projets (local, ignoré git)
│   └── projects.example.md ← Template versionné
└── docs/            ← Documentation (ce dossier)
    ├── architecture/
    ├── guides/
    └── reference/
```
