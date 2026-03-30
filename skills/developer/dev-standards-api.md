---
name: dev-standards-api
description: Standards spécifiques aux APIs publiques et d'intégration — versioning, pagination, gestion des erreurs, rate limiting, idempotence, contrats OpenAPI, breaking changes, webhooks.
---

# Skill — Standards API

## Rôle

Ce skill définit les bonnes pratiques spécifiques à la conception et l'implémentation
d'APIs publiques, partenaires ou d'intégration.
Il complète `dev-standards-backend.md` (architecture) et `dev-standards-security.md` (sécurité).

---

## Versioning

- **Prefixe d'URL** : `/v1/`, `/v2/` — approche recommandée pour les APIs REST publiques
- **Header** : `Accept-Version: v2` — acceptable pour les APIs internes
- Documenter la politique de support (durée de vie des versions, calendrier de dépréciation)
- Une version dépréciée retourne `Deprecation: true` et `Sunset: <date>` dans les headers
- Ne jamais supprimer une version sans avoir notifié les consommateurs avec un préavis documenté

```
Deprecation: true
Sunset: Sat, 31 Dec 2026 23:59:59 GMT
Link: <https://api.example.com/v2/docs>; rel="successor-version"
```

---

## Pagination

### Cursor-based (recommandé pour les grandes collections)

```json
{
  "data": [...],
  "pagination": {
    "cursor": "eyJpZCI6MTIzfQ==",
    "hasMore": true,
    "limit": 20
  }
}
```

- Stable lors d'insertions concurrentes
- Scalable — ne nécessite pas de `COUNT(*)`
- Cursor opaque (base64) — ne pas exposer le format interne

### Offset/limit (acceptable pour les petites collections)

```json
{
  "data": [...],
  "pagination": {
    "total": 247,
    "offset": 40,
    "limit": 20,
    "next": "/v1/resources?offset=60&limit=20",
    "prev": "/v1/resources?offset=20&limit=20"
  }
}
```

- Inclure `total` pour permettre la navigation par page
- Limiter `limit` à une valeur maximale configurable (ex: 100)
- Valider `offset` et `limit` — rejeter les valeurs négatives ou hors plage

---

## Format de réponse uniforme

### Succès

```json
{
  "data": { ... },
  "meta": {
    "requestId": "req_abc123",
    "timestamp": "2026-03-30T10:00:00Z"
  }
}
```

### Erreur

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Données de requête invalides",
    "details": [
      { "field": "email", "message": "Format invalide", "value": "not-an-email" }
    ],
    "requestId": "req_abc123"
  }
}
```

- `code` : constante machine-readable (snake_case ou SCREAMING_SNAKE_CASE) — stable entre versions
- `message` : description humaine lisible — peut évoluer
- `details` : liste des erreurs de validation champ par champ
- `requestId` : identifiant de corrélation pour les logs

---

## Codes HTTP sémantiques

| Situation | Code |
|-----------|------|
| Succès, retourne une ressource | 200 |
| Création réussie | 201 |
| Action réussie sans contenu retourné | 204 |
| Requête invalide (validation) | 400 |
| Non authentifié | 401 |
| Authentifié mais non autorisé | 403 |
| Ressource non trouvée | 404 |
| Conflit (doublon, état incompatible) | 409 |
| Entité non traitable (validation sémantique) | 422 |
| Trop de requêtes | 429 |
| Erreur serveur interne | 500 |
| Service temporairement indisponible | 503 |

Ne jamais retourner 200 avec un corps contenant `{ success: false }`.

---

## Idempotence

- `GET`, `HEAD`, `OPTIONS`, `DELETE` : idempotents par définition
- `PUT` : idempotent — appliquer plusieurs fois produit le même résultat
- `PATCH` : idempotent si la modification est absolue (set), non idempotent si relative (increment)
- `POST` : non idempotent par défaut — utiliser une clé d'idempotence pour les opérations critiques

```
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
```

```typescript
// ✅ Gestion de la clé d'idempotence
async function createOrder(dto: CreateOrderDto, idempotencyKey: string) {
  const existing = await cache.get(`idem:${idempotencyKey}`)
  if (existing) return JSON.parse(existing) // replay de la réponse précédente

  const result = await orderService.create(dto)
  await cache.set(`idem:${idempotencyKey}`, JSON.stringify(result), { ttl: 86400 })
  return result
}
```

---

## Contrat OpenAPI

- Définir le contrat **avant** d'implémenter (schema-first)
- Chaque endpoint a une description, des paramètres typés et des réponses documentées
- Utiliser `$ref` pour réutiliser les schémas communs — pas de copier-coller

```yaml
# ✅ Endpoint documenté avec tous les cas
paths:
  /v1/users/{id}:
    get:
      summary: Récupérer un utilisateur
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Utilisateur trouvé
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserResponse'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '403':
          $ref: '#/components/responses/Forbidden'
        '404':
          $ref: '#/components/responses/NotFound'
```

---

## Breaking changes

Un breaking change est toute modification qui casse un consommateur existant :

| Type | Exemples |
|------|---------|
| Suppression | Champ supprimé, endpoint supprimé, valeur d'enum retirée |
| Renommage | Champ renommé, endpoint renommé |
| Changement de type | `string` → `number`, `object` → `array` |
| Contrainte plus stricte | Validation ajoutée, champ devenu obligatoire |
| Comportement modifié | Sémantique d'un code HTTP changée |

**Règle :** tout breaking change nécessite une nouvelle version majeure.

**Évolutions non-breaking (rétrocompatibles) :**
- Ajout d'un champ optionnel en réponse
- Ajout d'un endpoint
- Ajout d'une valeur d'enum (si les consommateurs ignorent les valeurs inconnues)
- Contrainte plus souple (champ optionnel devient nullable)

---

## Webhooks sortants

```typescript
// ✅ Webhook sécurisé et fiable
async function sendWebhook(url: string, payload: object, secret: string) {
  const body = JSON.stringify(payload)
  const timestamp = Date.now().toString()
  const signature = createHmac('sha256', secret)
    .update(`${timestamp}.${body}`)
    .digest('hex')

  await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Webhook-Timestamp': timestamp,
      'X-Webhook-Signature': `sha256=${signature}`,
    },
    body,
    signal: AbortSignal.timeout(5000), // timeout 5s
  })
}
```

- Signer les payloads (HMAC-SHA256) — permettre aux consommateurs de vérifier l'authenticité
- Timeout explicite sur chaque appel
- Retry avec backoff exponentiel sur les erreurs 5xx (pas sur les 4xx)
- Logger le résultat de chaque tentative d'envoi
- Exposer un endpoint de test pour que les consommateurs puissent valider leur intégration

---

## Rate limiting (côté API exposée)

- Retourner les headers standards :
  ```
  X-RateLimit-Limit: 100
  X-RateLimit-Remaining: 42
  X-RateLimit-Reset: 1711790400
  Retry-After: 60
  ```
- Différencier les limites par tier (free, pro, enterprise)
- Documenter les limites dans l'OpenAPI et le guide d'intégration

---

## Ce que tu ne fais PAS

- Modifier un contrat d'API existant sans versionner
- Retourner des données non nécessaires dans les réponses (over-fetching)
- Exposer des IDs internes séquentiels — utiliser des UUID ou des identifiants opaques
- Implémenter une auth maison — déléguer à un middleware d'authentification éprouvé
- Livrer un endpoint sans documentation OpenAPI à jour
