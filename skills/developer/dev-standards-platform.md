---
name: dev-standards-platform
description: Standards de développement platform — infrastructure as code (Terraform, Pulumi), orchestration Kubernetes, GitOps (ArgoCD, Flux), gestion des secrets à l'échelle et parité des environnements.
---

# Skill — Standards Platform

## Rôle

Ce skill définit les bonnes pratiques pour la conception et l'implémentation
de l'infrastructure as code, de l'orchestration de conteneurs et du GitOps.
Il complète `dev-standards-devops.md` en couvrant l'infrastructure qui fait
tourner les applications, là où DevOps couvre les pipelines et la containerisation.

---

## Règles absolues

❌ Jamais de modification manuelle d'une ressource d'infrastructure en production
❌ Jamais de `kubectl apply` manuel sur un cluster de production — tout passe par GitOps ou un pipeline approuvé
❌ Jamais de secrets en clair dans le code Terraform, Helm ou les manifests K8s
❌ Jamais de droits plus larges que nécessaire (principe du moindre privilège)
✅ Tout changement d'infrastructure est versionné, reviewé et tracé
✅ Les environnements sont reproductibles — dev ≈ staging ≈ production (différences documentées)
✅ Chaque ressource a un owner et un contexte documentés

---

## Terraform

### Structure des modules

```
infrastructure/
├── modules/                    ← modules réutilisables
│   ├── network/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── database/
│   └── kubernetes-cluster/
├── environments/               ← configurations par environnement
│   ├── dev/
│   │   ├── main.tf             ← appelle les modules
│   │   ├── variables.tf
│   │   └── terraform.tfvars    ← valeurs (non versionné si secrets)
│   ├── staging/
│   └── production/
└── shared/                     ← ressources partagées (DNS, registry, etc.)
```

### Bonnes pratiques

- Un module = une responsabilité (réseau, base de données, cluster, etc.)
- Les modules sont versionnés et référencés avec une version fixe :
  `source = "git::https://github.com/org/infra-modules.git//network?ref=v1.2.0"`
- Variables obligatoires documentées avec `description` et `type`
- Outputs explicites — ne pas exposer les secrets en output
- State remote avec verrouillage (S3 + DynamoDB, GCS, Terraform Cloud)
- Un workspace Terraform = un environnement

```hcl
# ✅ Variable bien documentée
variable "cluster_node_count" {
  description = "Nombre de nœuds workers du cluster Kubernetes"
  type        = number
  default     = 3

  validation {
    condition     = var.cluster_node_count >= 1 && var.cluster_node_count <= 20
    error_message = "Le nombre de nœuds doit être entre 1 et 20."
  }
}
```

### Cycle de vie des changements

1. Modifier le code Terraform sur une branche
2. `terraform plan` — revoir les changements avant d'appliquer
3. PR avec le plan en commentaire automatique (via CI)
4. Review humaine obligatoire pour les changements en production
5. `terraform apply` via pipeline uniquement (pas de `terraform apply` local sur prod)

### Drift detection

- Configurer `terraform plan` en mode lecture seule en CI pour détecter les drifts
- Alerter si des ressources ont été modifiées hors Terraform
- Documenter les exceptions justifiées (ressources managées en dehors de Terraform)

---

## Kubernetes

### Structure des manifests

```
k8s/
├── base/                       ← configuration commune (Kustomize)
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── kustomization.yaml
└── overlays/                   ← surcharges par environnement
    ├── dev/
    ├── staging/
    └── production/
```

### Règles de déploiement

```yaml
# ✅ Deployment bien configuré
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  labels:
    app: my-app
    version: "1.2.3"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    spec:
      # Utilisateur non-root
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
      containers:
        - name: my-app
          image: my-registry/my-app:abc1234  # SHA ou tag précis — jamais latest
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: database-url
```

### RBAC — Principe du moindre privilège

- Un ServiceAccount par application — jamais le ServiceAccount `default`
- Les rôles sont définis au niveau namespace (Role) sauf nécessité absolue (ClusterRole)
- Auditer les ClusterRoleBindings régulièrement
- Pas de `verbs: ["*"]` ni de `resources: ["*"]` sauf cas documenté et validé

```yaml
# ✅ RBAC minimal
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-reader
  namespace: production
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list"]
```

### Network Policies

- Par défaut : `deny all` entre namespaces
- Ouvrir explicitement uniquement les flux nécessaires
- Documenter chaque Network Policy avec son justification

### Resource Quotas et Limits

- Chaque namespace a un ResourceQuota défini
- Chaque container a des `requests` et `limits` définis
- Les limits ne dépassent pas 4x les requests (éviter le throttling brutal)

---

## Helm

### Structure d'un chart

```
my-chart/
├── Chart.yaml          ← métadonnées (nom, version, description)
├── values.yaml         ← valeurs par défaut
├── values-staging.yaml ← surcharges staging
├── values-prod.yaml    ← surcharges production
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── configmap.yaml
    ├── secret.yaml     ← référence à External Secrets, pas de secrets en clair
    └── _helpers.tpl    ← templates réutilisables
```

### Bonnes pratiques

- Versionner le chart avec SemVer (`version` dans `Chart.yaml`)
- Les valeurs sensibles ne sont jamais dans `values.yaml` — utiliser External Secrets
- Toujours utiliser `helm diff` avant un `helm upgrade` en production
- Les releases Helm sont nommées de façon cohérente : `<app>-<env>` (ex: `api-production`)

---

## GitOps

### Principes

- Le dépôt Git est la **source de vérité unique** de l'état de l'infrastructure
- Tout changement en production passe par une PR, pas par une commande manuelle
- L'état réel du cluster doit converger vers l'état décrit dans Git
- Les opérations manuelles d'urgence sont documentées et suivies d'un commit de synchronisation

### ArgoCD

```yaml
# Application ArgoCD — sync automatique sur staging, manuel sur prod
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app-production
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/infra
    targetRevision: main
    path: k8s/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:       # uniquement sur staging
      prune: true
      selfHeal: true
    # Sur production : sync manuel ou via pipeline approuvé
```

---

## Gestion des secrets à l'échelle

### External Secrets Operator

Synchronise les secrets depuis un gestionnaire externe (Vault, AWS Secrets Manager, etc.)
vers des Secrets Kubernetes. Les secrets ne sont jamais stockés dans Git.

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-secrets
  data:
    - secretKey: database-url
      remoteRef:
        key: production/app
        property: database_url
```

### Vault

- Un path par application et par environnement : `secret/production/app-name/`
- Rotation automatique des credentials base de données (Dynamic Secrets)
- Audit log activé sur toutes les opérations
- Principe du moindre privilège sur les policies Vault

---

## Parité des environnements

| Aspect | Dev | Staging | Production |
|--------|-----|---------|------------|
| Infrastructure | Minikube / K3s / Kind | Cluster dédié | Cluster dédié |
| Données | Fixtures ou anonymisées | Copie anonymisée | Réelles |
| Secrets | `.env` local | External Secrets | External Secrets |
| Replicas | 1 | 2 | ≥ 3 |
| Différences documentées | obligatoire | obligatoire | obligatoire |

Toute différence entre environnements est documentée dans `docs/infrastructure/environments.md`.

---

## Ce que tu ne fais PAS

- Modifier des ressources en production sans pipeline validé ou PR approuvée
- Stocker des secrets dans Git, même chiffrés avec une méthode non auditée
- Créer des ressources Kubernetes sans `requests`/`limits` définis
- Utiliser `latest` comme tag d'image dans les manifests
- Appliquer un plan Terraform sans l'avoir relu — même en environnement de dev
- Contourner GitOps "pour aller plus vite" en cas d'incident (documenter l'action manuelle immédiatement)
