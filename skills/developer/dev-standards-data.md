---
name: dev-standards-data
description: Standards de développement data — Python data science, pandas, SQL, pipelines ETL, dbt, Airflow, Spark, et cycle de vie des modèles ML.
---

# Skill — Standards Data / ML

## Rôle

Ce skill définit les bonnes pratiques pour le développement data et machine learning.
Il complète `dev-standards-universal.md` et s'applique aux projets data, analytics,
pipelines ETL et machine learning.

---

## 🔒 Règle absolue — Données et modèles

Pour tout sujet lié aux données et modèles ML, tu ne prends JAMAIS de décision seul.

**Sont concernés :**
- Choix du schéma de données ou du modèle de feature
- Stratégie de partitionnement ou d'indexation
- Choix d'algorithme ML ou de librairie
- Stratégie de ré-entraînement ou de mise à jour de modèle
- Architecture de pipeline (batch vs streaming)

**Processus obligatoire :**
1. Détecter le besoin
2. Présenter 2-3 options avec trade-offs explicites
3. Attendre validation explicite
4. N'implémenter qu'après confirmation

---

## Python — Standards généraux

- Python ≥ 3.10 — utiliser les features modernes (match, type hints natifs)
- Typage systématique : toutes les fonctions ont des annotations de type
- `mypy` ou `pyright` activé en mode strict sur les modules critiques
- Environnements isolés : `venv`, `poetry` ou `uv` — jamais d'installation globale
- Formatage : `ruff` (lint + format) — remplace `black` + `flake8` + `isort`
- Pas de `print()` dans le code de production — utiliser `logging`

```python
# ✅ Bon
def compute_mean(values: list[float]) -> float:
    if not values:
        raise ValueError("La liste ne peut pas être vide")
    return sum(values) / len(values)

# ❌ Mauvais
def compute_mean(values):
    return sum(values) / len(values)
```

---

## Pandas et traitement de données

### Bonnes pratiques

- Toujours vérifier le schéma à l'entrée (dtypes, colonnes attendues)
- Préférer les opérations vectorisées aux boucles `for` sur les DataFrames
- Éviter `iterrows()` et `itertuples()` sur les grands datasets — utiliser `apply()` ou vectorisation
- Copier explicitement quand nécessaire (`df.copy()`) pour éviter les SettingWithCopyWarning
- Nommer les étapes de transformation de façon explicite

```python
# ✅ Vectorisé
df["prix_ttc"] = df["prix_ht"] * (1 + df["taux_tva"])

# ❌ Boucle inutile
for i, row in df.iterrows():
    df.at[i, "prix_ttc"] = row["prix_ht"] * (1 + row["taux_tva"])
```

### Validation des données

- Valider les DataFrames en entrée avec `pandera` ou `pydantic` (v2)
- Définir un schéma explicite pour chaque source de données
- Signaler (log + raise) les données inattendues — ne jamais les ignorer silencieusement

```python
import pandera as pa

schema = pa.DataFrameSchema({
    "prix_ht": pa.Column(float, pa.Check.greater_than(0)),
    "taux_tva": pa.Column(float, pa.Check.in_range(0, 1)),
})
```

---

## SQL

- Toujours utiliser des requêtes paramétrées (jamais de concaténation de chaînes)
- Nommer les CTEs de façon explicite et documentée
- Éviter `SELECT *` en production — lister les colonnes nécessaires
- Documenter les requêtes complexes (business logic non évidente)
- Tester les requêtes critiques avec des fixtures de données connues

```sql
-- ✅ CTE nommée et documentée
WITH commandes_du_mois AS (
    -- Commandes validées sur le mois en cours
    SELECT id, client_id, montant_ttc
    FROM commandes
    WHERE statut = 'validee'
      AND date_commande >= DATE_TRUNC('month', CURRENT_DATE)
)
SELECT client_id, SUM(montant_ttc) AS chiffre_affaires
FROM commandes_du_mois
GROUP BY client_id;
```

---

## Pipelines ETL

### Structure recommandée

```
pipeline/
├── extract/        ← Connexions aux sources (DB, API, fichiers)
├── transform/      ← Logique de transformation pure et testable
├── load/           ← Écriture vers la destination
├── models/         ← Schémas et contrats de données
└── tests/          ← Tests unitaires des transformations
```

### Principes

- **Idempotence** : un pipeline exécuté plusieurs fois produit le même résultat
- **Atomicité** : soit tout passe, soit rien — pas d'état partiel
- **Observabilité** : chaque étape loggue son volume d'entrée/sortie et sa durée
- **Isolation** : les transformations sont des fonctions pures testables sans infra

---

## dbt

- Un modèle = une responsabilité (pas de modèle "fourre-tout")
- Utiliser les layers : `staging` → `intermediate` → `mart`
  - `staging` : renommage, typage, nettoyage basique depuis les sources brutes
  - `intermediate` : jointures et agrégations intermédiaires
  - `mart` : tables exposées aux utilisateurs finaux
- Documenter chaque modèle dans `schema.yml` (description + tests)
- Tests dbt obligatoires : `not_null`, `unique` sur toutes les clés primaires
- Matérialisation par défaut : `view` sauf justification (`table`, `incremental`)

```yaml
# schema.yml
models:
  - name: mart_commandes
    description: "Commandes validées agrégées par client et par mois"
    columns:
      - name: client_id
        tests:
          - not_null
          - relationships:
              to: ref('dim_clients')
              field: id
      - name: chiffre_affaires
        tests:
          - not_null
```

---

## Apache Airflow / Orchestration

- Un DAG = un pipeline métier distinct
- Toujours définir `start_date`, `schedule_interval` et `catchup=False` explicitement
- Les tâches sont atomiques et idempotentes
- Utiliser `TaskFlow API` (décorateurs `@task`) plutôt que les opérateurs bas niveau quand possible
- Pas de logique métier dans la définition du DAG — uniquement l'orchestration
- Les secrets sont injectés via Airflow Variables ou Connections (jamais en dur)

```python
from airflow.decorators import dag, task
from datetime import datetime

@dag(schedule="@daily", start_date=datetime(2024, 1, 1), catchup=False)
def pipeline_commandes():

    @task()
    def extraire() -> list[dict]:
        # extraction depuis la source
        ...

    @task()
    def transformer(commandes: list[dict]) -> list[dict]:
        # transformation pure
        ...

    @task()
    def charger(commandes: list[dict]) -> None:
        # chargement vers la destination
        ...

    charger(transformer(extraire()))
```

---

## Apache Spark / PySpark

- Utiliser les DataFrames API (pas RDD sauf cas extrême justifié)
- Éviter les UDFs Python si une fonction Spark native existe — les UDFs sont lentes
- Partitionner les données selon les colonnes de filtrage les plus fréquentes
- Éviter les shuffles inutiles (`groupBy`, `join`) — partitionner en amont
- Tester la logique avec des DataFrames locaux (pas besoin de cluster pour les tests)
- Utiliser `spark.sql` pour les transformations complexes et documentées

---

## Machine Learning — Cycle de vie

### Expérimentation

- Tracker toutes les expériences (MLflow, Weights & Biases, ou équivalent)
- Versionner les datasets utilisés pour l'entraînement
- Fixer les seeds aléatoires pour la reproductibilité (`random_state`, `torch.manual_seed`)
- Séparer strictement train / validation / test — pas de data leakage

### Code ML

- Séparer le prétraitement (transformations reproductibles) de l'entraînement
- Encapsuler le pipeline complet (prétraitement + modèle) dans un `sklearn.Pipeline` ou équivalent
- Pas de magic numbers dans les hyperparamètres — utiliser des configs (yaml, dataclass)
- Documenter les choix d'algorithme et les métriques de sélection

```python
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression

pipeline = Pipeline([
    ("scaler", StandardScaler()),
    ("classifier", LogisticRegression(random_state=42, max_iter=1000)),
])
```

### Mise en production

- Versionner les modèles enregistrés (MLflow Model Registry ou équivalent)
- Monitorer la dérive des données en production (data drift, concept drift)
- Définir des seuils d'alerte et un processus de ré-entraînement
- Documenter les limites connues du modèle (biais, périmètre de validité)

---

## Tests data

- Tester les transformations avec des fixtures de données connues (entrée → sortie attendue)
- Tester les cas limites : DataFrame vide, valeurs nulles, types inattendus
- Ne pas tester contre une vraie base de données — utiliser SQLite in-memory ou des fichiers parquet de test
- Utiliser `pytest` avec `pytest-mock` pour les dépendances externes

```python
def test_calcul_prix_ttc():
    # Arrange
    df = pd.DataFrame({"prix_ht": [100.0, 50.0], "taux_tva": [0.2, 0.1]})

    # Act
    result = calculer_prix_ttc(df)

    # Assert
    assert result["prix_ttc"].tolist() == [120.0, 55.0]
```

---

## Ce que tu ne fais PAS

- Entraîner des modèles en production sans validation humaine préalable
- Modifier des données sources brutes (toujours travailler sur des copies ou des vues)
- Committer des datasets volumineux dans git — utiliser DVC, S3, ou un data lake
- Utiliser des données personnelles réelles dans les environnements de test
