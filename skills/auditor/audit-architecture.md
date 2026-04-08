---
name: audit-architecture
description: Référentiel d'architecture logicielle — principes SOLID, couplage, cohésion, dette technique, patterns, maintenabilité et évolutivité du code.
---

# Skill — Audit Architecture

## Référentiels couverts

- **Principes SOLID** — fondements de la conception orientée objet
- **Clean Architecture** / Hexagonal Architecture — séparation des couches
- **Design Patterns** (GoF) — patterns et anti-patterns courants
- **Métriques de qualité** — couplage, cohésion, complexité cyclomatique
- **Technical Debt** — dette technique et ses catégories

---

## Principes SOLID

### S — Single Responsibility Principle (SRP)

- [ ] Chaque classe/module a une et une seule raison de changer
- [ ] Les classes ne mélangent pas logique métier, persistance et présentation
- [ ] Les contrôleurs ne contiennent pas de logique métier (délèguent à des services)
- [ ] Les services ne font pas directement des requêtes SQL (délèguent aux repositories)

**Anti-patterns à détecter :**
- Classes > 300 lignes sans justification claire
- Méthodes > 50 lignes qui font plusieurs choses
- Noms de classe vagues : `Manager`, `Helper`, `Utils`, `Misc`

### O — Open/Closed Principle (OCP)

- [ ] L'ajout d'un nouveau cas d'usage n'oblige pas à modifier du code existant validé
- [ ] Les `switch/case` ou chaînes `if/elseif` sur des types métier peuvent être remplacés par du polymorphisme
- [ ] Les stratégies (algorithmes interchangeables) utilisent le pattern Strategy ou sont injectées

**Anti-patterns à détecter :**
- `switch ($type) { case 'A': ... case 'B': ... }` sur des types extensibles
- Conditions multiples dans le code métier pour gérer des variantes

### L — Liskov Substitution Principle (LSP)

- [ ] Les sous-classes respectent le contrat de la classe parente
- [ ] L'héritage n'est pas utilisé uniquement pour la réutilisation de code (préférer la composition)
- [ ] Les implémentations d'interface ne lèvent pas d'exceptions inattendues sur des méthodes définies

**Anti-patterns à détecter :**
- Méthode d'interface implémentée avec `throw new NotImplementedException()`
- Sous-classe qui annule le comportement de la classe parente (`return null` sur une méthode qui devrait retourner un objet)

### I — Interface Segregation Principle (ISP)

- [ ] Les interfaces sont spécialisées (pas d'interface "fourre-tout" avec 20 méthodes)
- [ ] Les implémentations ne dépendent pas de méthodes qu'elles n'utilisent pas
- [ ] Les DTOs et Value Objects sont distincts des entités persistées

**Anti-patterns à détecter :**
- Interface avec > 10 méthodes non cohésives
- Classe qui implémente une interface mais laisse plusieurs méthodes vides ou en `throw`

### D — Dependency Inversion Principle (DIP)

- [ ] Les modules de haut niveau dépendent d'abstractions (interfaces), pas d'implémentations concrètes
- [ ] Les dépendances sont injectées (injection de dépendances) plutôt qu'instanciées dans le code
- [ ] Les classes ne font pas `new ConcreteService()` dans leur constructeur ou méthodes (sauf Value Objects)

**Anti-patterns à détecter :**
- `new DatabaseConnection()` ou `new HttpClient()` dans un service métier
- Dépendances importées directement sans injection ni interface

---

## Checklist — Couplage et cohésion

### Couplage afférent et efférent

- [ ] Les modules centraux (core domain) n'ont pas de dépendances vers des couches infrastructure
- [ ] Les dépendances circulaires entre modules sont absentes
- [ ] Le couplage entre modules métier distants passe par des interfaces ou des événements (pas d'import direct)

**Indicateurs de couplage excessif :**
- Un module importe depuis > 10 autres modules différents
- Modifier un fichier déclenche des cascades de modifications dans d'autres modules
- Tests unitaires nécessitent de nombreux mocks complexes

### Cohésion

- [ ] Les fichiers d'un même répertoire ont une responsabilité thématique commune
- [ ] Les fonctions d'un même module travaillent sur les mêmes données
- [ ] Les constantes et helpers sont proches des modules qui les utilisent

---

## Checklist — Architecture en couches

### Séparation des couches (Clean / Hexagonal)

- [ ] La logique métier (domain) est isolée des frameworks et bibliothèques externes
- [ ] Les couches respectent la règle de dépendance : infrastructure → application → domain
- [ ] Les entités domain n'ont pas de dépendances vers les ORM, frameworks HTTP, ou services tiers
- [ ] Les adapters (repositories, controllers, gateways) sont dans des couches périphériques

**Structure attendue (exemple) :**
```
src/
├── domain/          ← Entités, Value Objects, interfaces des repositories
├── application/     ← Use cases, DTOs, orchestration
├── infrastructure/  ← Implémentations (DB, HTTP, fichiers)
└── presentation/    ← Controllers, serializers, vues
```

### Gestion des erreurs par couche

- [ ] Les exceptions techniques (DB, réseau) sont capturées dans l'infrastructure et converties en exceptions domain
- [ ] Les erreurs de validation sont gérées dans la couche application ou présentation
- [ ] Les erreurs ne traversent pas les couches sans transformation

---

## Checklist — Patterns courants

### Patterns bénéfiques à vérifier

- [ ] **Repository Pattern** : accès aux données centralisé, testable
- [ ] **Factory Pattern** : création d'objets complexes séparée de leur utilisation
- [ ] **Strategy Pattern** : algorithmes interchangeables sans condition
- [ ] **Observer/Event** : découplage entre émetteurs et consommateurs
- [ ] **Command Pattern** : actions encapsulées (CQRS, queues)

### Anti-patterns à signaler

| Anti-pattern | Description | Criticité |
|-------------|-------------|----------|
| **God Object** | Classe qui fait tout, > 500 lignes | 🟠 Majeur |
| **Spaghetti Code** | Logique imbriquée profondément, impossible à suivre | 🟠 Majeur |
| **Shotgun Surgery** | Chaque modification touche de nombreux fichiers disparates | 🟠 Majeur |
| **Feature Envy** | Méthode qui accède plus aux données d'un autre objet que du sien | 🟡 Mineur |
| **Data Clump** | Groupe de variables toujours passées ensemble (candidat à un objet) | 🟡 Mineur |
| **Primitive Obsession** | Utilisation de types primitifs là où des Value Objects seraient plus expressifs | 🟡 Mineur |
| **Magic Numbers** | Valeurs numériques ou chaînes sans constante nommée | 🟡 Mineur |
| **Dead Code** | Code commenté ou jamais exécuté | 🟡 Mineur |
| **Circular Dependency** | Modules A → B → A | 🔴 Critique |
| **Leaky Abstraction** | L'implémentation interne fuit dans l'interface publique | 🟠 Majeur |

---

## Checklist — Complexité et maintenabilité

### Complexité cyclomatique

- [ ] Les fonctions/méthodes ont une complexité cyclomatique ≤ 10
  - Complexité = 1 + nombre de branches (if, for, while, case, catch, &&, ||)
  - > 10 : difficile à tester et à maintenir → refactoriser
  - > 20 : critique → refactorisation obligatoire
- [ ] Les fonctions font ≤ 30 lignes (hors commentaires et lignes vides)
- [ ] L'imbrication (indentation) ne dépasse pas 3-4 niveaux

### Tests et testabilité

- [ ] La couverture de tests est ≥ 70% sur le code métier (domaine + application)
- [ ] Les tests unitaires ne dépendent pas d'une base de données ou d'un réseau
- [ ] Les composants sont conçus pour être testables (DIP, injection)
- [ ] Les tests reflètent le comportement métier (pas le détail d'implémentation)
- [ ] Absence de "test de l'implémentation" (tester les internals d'une classe privée)

### Nommage et lisibilité

- [ ] Les noms expriment l'intention (pas `data`, `temp`, `obj`, `value`)
- [ ] Les noms de méthodes commencent par un verbe (`getUser`, `calculateTotal`, `isValid`)
- [ ] Les booléens sont préfixés (`isActive`, `hasPermission`, `canDelete`)
- [ ] Les constantes sont en SCREAMING_SNAKE_CASE avec nom expressif
- [ ] Les abréviations non standards sont évitées (`usrMgr` → `userManager`)

---

## Checklist — Dette technique

### Catégories de dette technique (modèle Cunningham étendu)

| Catégorie | Description | Indicateurs |
|-----------|-------------|-------------|
| **Dette délibérée** | Raccourcis intentionnels sous contrainte de temps | Commentaires `// TODO:`, `// FIXME:`, `// HACK:` |
| **Dette accidentelle** | Mauvaises décisions non intentionnelles | Duplications, couplage non vu |
| **Dette de bit rot** | Code devenu obsolète par évolution du contexte | Dépendances dépréciées, patterns abandonnés |
| **Dette d'architecture** | Structure globale inadaptée | Monolithe à séparer, modules trop couplés |

### Identification de la dette

- [ ] Les `TODO`, `FIXME`, `HACK`, `XXX` sont recensés et quantifiés
- [ ] Les dépendances dépréciées ou abandonnées sont identifiées
- [ ] Les modules avec le plus grand nombre de modifications historiques sont identifiés (hot spots)
- [ ] La duplication de code est mesurée (cible : ≤ 5% de duplication globale)

### Priorisation de la dette

La dette est à rembourser selon la formule :
**Priorité = Impact (coût du maintien) × Probabilité de modification**

- 🔴 Critique : code central très modifié avec dette architecturale profonde
- 🟠 Majeur : code important avec dette significative non encore douloureuse
- 🟡 Mineur : code périphérique peu modifié avec petites imperfections

---

## Checklist — Conventions et cohérence

- [ ] Un seul style de gestion des erreurs (exceptions vs codes de retour vs Result type) — cohérent dans tout le projet
- [ ] Les conventions de nommage sont uniformes dans tout le codebase
- [ ] La structure des répertoires est cohérente avec l'architecture annoncée
- [ ] Les patterns utilisés sont documentés (ADR — Architecture Decision Records si disponible)
- [ ] Le README ou la documentation architecture décrit les choix structurels majeurs

---

> Les outils d'analyse statique (phpmd, eslint, radon, jscpd, SonarQube, etc.)
> sont référencés dans `docs/reference/audit-tools.md` pour usage humain.

## Ce que tu ne fais PAS dans ce domaine

- Proposer une réécriture complète sans analyse coût/bénéfice
- Appliquer les patterns pour eux-mêmes quand la simplicité suffit ("over-engineering")
- Ignorer les contraintes historiques du projet (dette héritée sans contexte)
- Évaluer l'équipe ou les développeurs — seul le code est analysé
