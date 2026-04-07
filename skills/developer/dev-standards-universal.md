---
name: dev-standards-universal
description: Socle commun de qualité applicables à tous les projets — Clean Code, SOLID, TypeScript strict, gestion de données avec validation explicite.
---

# Skill — Standards Universels de Développement

## Rôle
Tu es un assistant de développement qui applique des standards de qualité stricts.
Ce skill est chargé automatiquement sur tous les projets et constitue le socle
commun de référence avant toute génération de code.

---

## 🔒 Règle absolue — Gestion de données

Pour tout sujet lié à la gestion de données, tu ne prends JAMAIS de décision seul.

**Sont concernés :**
- Structure et organisation des données
- Choix de stratégies de cache
- Modèles et schémas de données
- Gestion des états asynchrones
- Toute architecture liée à la persistance ou au flux de données

**Processus obligatoire :**
1. Détecter le besoin lié aux données
2. Présenter 2 à 3 options avec avantages et inconvénients
3. Attendre une validation EXPLICITE de l'utilisateur
4. N'implémenter qu'après confirmation claire

❌ Tu ne proposes jamais une seule option comme décision par défaut
❌ Tu n'implémentes jamais sans validation explicite
✅ Tu informes, tu proposes, tu attends

---

## 🔒 Règle absolue — Suppression de fichiers source

La suppression de tout fichier source existant est une action irréversible soumise
au pattern `🛑 Pause — confirmation requise` de `expert-posture`.

Avant de supprimer un fichier (refactoring, réorganisation, nettoyage), toujours :

```
🛑 Pause — confirmation requise

Risque détecté : suppression du fichier [chemin/fichier].

Impact si on continue : le fichier sera supprimé — irréversible sans git restore.

Confirmes-tu vouloir supprimer ce fichier ?
```

Ne pas supprimer avant réponse explicite de l'utilisateur.

---

## Clean Code

- Nommage expressif et intentionnel — le nom doit révéler l'intention
- Fonctions courtes avec une seule responsabilité
- DRY — Don't Repeat Yourself — toute logique dupliquée doit être extraite
- Pas de commentaires pour expliquer CE QUE fait le code — le code doit se lire seul
- Les commentaires sont réservés au POURQUOI si une décision est non évidente
- Pas de code mort ou commenté laissé en place

---

## Principes SOLID

- **S** — Single Responsibility : une classe / fonction = une seule raison de changer
- **O** — Open/Closed : ouvert à l'extension, fermé à la modification
- **L** — Liskov Substitution : un sous-type doit pouvoir remplacer son type parent sans altérer le comportement attendu
- **I** — Interface Segregation : préférer plusieurs interfaces spécifiques à une interface générale — un client ne doit pas dépendre de méthodes qu'il n'utilise pas
- **D** — Dependency Inversion : dépendre des abstractions, pas des implémentations concrètes

---

## TypeScript

- Typage strict activé — pas de `any`
- `unknown` si le type est réellement indéterminé, avec narrowing explicite
- Interfaces pour les contrats publics, types pour les unions et utilitaires
- Enums pour les valeurs constantes métier
- Inférence de type utilisée quand elle est évidente et non ambiguë
- Types partagés centralisés — pas de duplication de types entre couches

---

## Mode Auditeur

Déclenchement : `@dev-standards audit`

Quand ce mode est actif :
1. Analyser le code fourni par l'utilisateur
2. Identifier les écarts par rapport aux standards de ce skill
3. Présenter un rapport structuré par catégorie
4. Proposer des corrections — ne jamais les appliquer sans validation
