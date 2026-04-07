---
name: dev-standards-backend
description: Bonnes pratiques backend agnostiques du framework — architecture en couches, API, sécurité, gestion des erreurs.
---

# Skill — Standards Backend (Agnostique)

## Rôle
Ce skill définit les bonnes pratiques backend indépendantes du framework.
Il complète `dev-standards-universal.md`.

---

## 🔒 Gestion de données — Règle héritée

Toute décision liée aux données est soumise à validation explicite.

**Spécifique backend :**
- Structure des repositories
- Choix et configuration ORM
- Stratégie de requêtes (eager/lazy loading)
- Modèles et schémas de données
- Migrations et évolutions de schéma

## 🔒 Migrations destructrices — Règle absolue

Toute migration contenant une opération destructrice irréversible est soumise à une
pause de confirmation obligatoire selon le pattern `🛑 Pause — confirmation requise`
de `expert-posture`.

**Sont concernés :**
- `DROP TABLE`, `DROP COLUMN`, `DROP INDEX`, `DROP SCHEMA`
- `TRUNCATE`
- `DELETE` sans clause `WHERE` (suppression de toutes les lignes)
- Renommage d'une colonne référencée par du code existant

**Format obligatoire :**
```
🛑 Pause — confirmation requise

Risque détecté : la migration contient [opération destructrice] sur [table/colonne].

Impact si on continue : suppression définitive des données — irréversible sans backup.

Confirmes-tu vouloir poursuivre avec cette migration destructrice ?
```

Ne pas générer ni exécuter la migration avant réponse explicite de l'utilisateur.

---

## Architecture

- Séparation stricte des couches : Controller → Service → Repository
- Les controllers reçoivent, valident, délèguent — pas de logique métier
- Les services contiennent la logique métier — pas de requêtes directes
- Les repositories gèrent l'accès aux données — pas de logique métier
- Pas de saut de couche — un controller n'appelle pas directement un repository

---

## API

- Codes HTTP sémantiques et cohérents
- Réponses typées et structurées de manière uniforme
- Validation systématique des inputs avant traitement
- DTOs distincts pour les entrées et les sorties
- Pas d'exposition directe des modèles de base de données en réponse

---

## Sécurité

- Jamais de secrets, tokens ou credentials dans le code source
- Variables d'environnement typées et validées au démarrage
- Sanitization de tous les inputs utilisateur
- Pas de messages d'erreur techniques exposés au client
- Logs suffisants pour le débogage — sans données sensibles

---

## TypeScript Backend

- DTOs typés pour toutes les entrées et sorties
- Pas de `any` — `unknown` avec narrowing si nécessaire
- Types partagés entre couches via un module commun
- Pas de cast forcé (`as Type`) sans vérification

---

## Gestion des erreurs

- Toutes les erreurs sont catchées et traitées explicitement
- Pas de `try/catch` vide
- Erreurs métier distinguées des erreurs techniques
- Un handler global centralise le formatage des erreurs HTTP
