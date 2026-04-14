> 🇬🇧 [Read in English](providers.en.md)

# Support multi-fournisseurs LLM

OpenCode Hub supporte plusieurs fournisseurs LLM, vous permettant de choisir la meilleure solution selon vos besoins. Ce guide explique comment configurer et utiliser les différents fournisseurs.

## Vue d'ensemble

### Fournisseurs supportés

| Fournisseur | Type | Cibles | Credential | URL de base par défaut |
|-------------|------|--------|------------|------------------------|
| **Anthropic** | Natif | OpenCode, Claude Code | Clé API | N/A |
| **MammouthAI** | OpenAI-compatible (litellm) | OpenCode | Clé API | `https://api.mammouth.ai/v1` |
| **GitHub Models** | OpenAI-compatible (litellm) | OpenCode | Clé API | `https://models.inference.ai.azure.com` |
| **AWS Bedrock** | Natif (`amazon-bedrock`) | OpenCode | Bearer token | N/A |
| **Ollama** | OpenAI-compatible (litellm) | OpenCode | Optionnel | `http://localhost:11434/v1` |

### Notes importantes

- **Limitation Claude Code** : Claude Code ne supporte que le fournisseur `anthropic` (contrainte architecturale). L'utilisation d'autres fournisseurs déclenchera un avertissement.
- **Priorité des modèles** : Les modèles sont résolus dans cet ordre : 1) Config projet → 2) Hub par défaut → 3) Variable d'env → 4) Hub opencode.model → 5) Fallback par défaut

## Configuration Levels

OpenCode Hub supports provider configuration at two levels:

### 1. Hub Level (Default for All Projects)

Set a provider that applies to all projects by default:

```bash
./oc.sh provider set-default
```

This prompts you to:
- Select a provider (1-5 or skip)
- Provide API credentials (if required)
- Optionally set a custom base URL

The configuration is stored in `config/hub.json` in the `default_provider` block:

```json
{
  "default_provider": {
    "name": "mammouth",
    "api_key": "sk-xxx...",
    "base_url": "https://api.mammouth.ai/v1",
    "model": ""
  }
}
```

**Note**: If an API key is configured, `config/hub.json` is automatically added to `.gitignore`.

### 2. Project Level (Per-Project Override)

Configure a different provider for a specific project:

```bash
./oc.sh init MY-PROJECT
# or
./oc.sh config set MY-PROJECT
```

During `oc init`, you'll be prompted for an optional project-level provider (step 4).

During `oc config set`, you can specify `--provider` and related flags:

```bash
./oc.sh config set MY-PROJECT --provider github-models --api-key sk-xxx
```

Project-level config is stored in `projects/api-keys.local.md` (not committed to git):

```
[MY-PROJECT]
provider=github-models
api_key=sk-xxx...
base_url=https://models.inference.ai.azure.com
model=claude-opus
```

## Command Reference

### `oc provider list`

Display all available providers with their status (default, configured, supported targets):

```bash
./oc.sh provider list
```

Example output:
```
Fournisseurs LLM disponibles

Anthropic (direct) ◆ (hub default)
  API Anthropic directe pour Claude models
  Cibles: ["opencode", "claude-code"]

MammouthAI
  Proxy OpenAI-compatible vers Claude (FR-hosted)
  Cibles: ["opencode"]
  Base URL: https://api.mammouth.ai/v1

...
```

### `oc provider set-default`

Configure interactivement le fournisseur par défaut du hub :

```bash
./oc.sh provider set-default
```

Vous serez invité à :
1. Sélectionner un fournisseur
2. Saisir les credentials (saisie masquée pour la sécurité)
3. Optionnellement saisir une URL de base personnalisée

La configuration est écrite dans `config/hub.json` **et `opencode.json` est régénéré immédiatement** — pas besoin de lancer `oc deploy` manuellement.

### `oc provider set <PROJECT_ID> [PROVIDER] [API_KEY] [BASE_URL]`

Configure a provider for a specific project:

```bash
# Interactive
./oc.sh provider set MY-PROJECT

# Non-interactive (direct)
./oc.sh provider set MY-PROJECT mammouth "sk-xxx" "https://api.mammouth.ai/v1"
```

If `PROVIDER`, `API_KEY`, or `BASE_URL` are omitted, you'll be prompted.

The configuration is written to `projects/api-keys.local.md`.

### `oc provider get <PROJECT_ID>`

Display the effective provider configuration for a project:

```bash
./oc.sh provider get MY-PROJECT
```

Example output:
```
Configuration effective pour MY-PROJECT

  Provider : mammouth
  Model    : claude-opus
  API Key  : sk-xxx****
  Base URL : https://api.mammouth.ai/v1
```

Shows the resolved configuration after merging project-level and hub-level settings.

## Provider Setup Guides

### Anthropic (Default)

**Supported targets**: OpenCode, Claude Code

1. Get your API key from [console.anthropic.com](https://console.anthropic.com)
2. Run `./oc.sh provider set-default` or `./oc.sh config set <PROJECT_ID>`
3. Choose "Anthropic" and enter your API key

### MammouthAI

**Supported targets**: OpenCode

MammouthAI is an OpenAI-compatible proxy hosted in France that works with Anthropic models.

1. Get your API key from [mammouth.ai](https://mammouth.ai)
2. Run `./oc.sh provider set-default`
3. Choose "MammouthAI" (option 2)
4. Enter your API key (default base URL will be used: `https://api.mammouth.ai/v1`)

```bash
# Or via config:
./oc.sh config set MY-PROJECT --provider mammouth --api-key sk-xxx
```

### GitHub Models

**Supported targets**: OpenCode

GitHub Models provides access to various models via the GitHub/Copilot API.

1. Get your token from [github.com/settings/tokens](https://github.com/settings/tokens)
2. Run `./oc.sh provider set-default`
3. Choose "GitHub Models" (option 3)
4. Enter your GitHub token
5. Optionally override the base URL (default: `https://models.inference.ai.azure.com`)

```bash
# Or via config:
./oc.sh config set MY-PROJECT \
  --provider github-models \
  --api-key ghp_xxx \
  --base-url https://models.inference.ai.azure.com
```

### AWS Bedrock

**Cibles supportées** : OpenCode

AWS Bedrock utilise le **provider natif `amazon-bedrock`** intégré à OpenCode. Il requiert un **bearer token Bedrock** (clé à long terme générée depuis la console Amazon Bedrock).

**Fonctionnement :**
- Le bearer token est stocké dans `config/hub.json` (jamais dans `opencode.json`)
- `opencode.json` est généré avec un bloc `amazon-bedrock` vide
- Au lancement via `oc start`, le token est injecté automatiquement comme `AWS_BEARER_TOKEN_BEDROCK`

1. Générez un bearer token depuis la [console Amazon Bedrock](https://console.aws.amazon.com/bedrock/) sous **API Keys**
2. Demandez l'accès aux modèles dans le **Model catalog**
3. Lancez `./oc.sh provider set-default`
4. Choisissez "AWS Bedrock (natif)" et entrez votre bearer token

Le `opencode.json` généré ressemblera à :
```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "amazon-bedrock/anthropic.claude-sonnet-4-5",
  "provider": {
    "amazon-bedrock": {}
  }
}
```

Au lancement, `oc start` injecte :
```bash
AWS_BEARER_TOKEN_BEDROCK=<token> opencode
```

```bash
# Ou configurer par projet :
./oc.sh config set MON-PROJET --provider bedrock --api-key <bearer-token>
```

### Ollama (Local)

**Supported targets**: OpenCode

Ollama allows you to run LLMs locally.

1. Install Ollama from [ollama.ai](https://ollama.ai)
2. Start the Ollama server: `ollama serve`
3. Run `./oc.sh provider set-default`
4. Choose "Ollama" (option 5)
5. The default base URL (`http://localhost:11434/v1`) will be used

```bash
# Or via config:
./oc.sh config set MY-PROJECT \
  --provider ollama \
  --base-url http://localhost:11434/v1
```

Note: Ollama doesn't require an API key, but one can be set for custom authentication layers.

## Workflows

### Using Different Providers for Different Projects

```bash
# Set hub default to Anthropic
./oc.sh provider set-default
# → Choose Anthropic

# Override specific project to use GitHub Models
./oc.sh config set MY-PYTHON-PROJECT --provider github-models --api-key ghp_xxx

# Another project uses MammouthAI
./oc.sh config set MY-JS-PROJECT --provider mammouth --api-key sk-xxx
```

### Switching Providers

To change a provider configuration:

```bash
# For hub default:
./oc.sh provider set-default

# For a project:
./oc.sh config set MY-PROJECT
# → Follow prompts to update provider/key/model
```

### Using Local Ollama for Development

```bash
# Start Ollama (in a separate terminal):
ollama serve

# Configure your project to use Ollama:
./oc.sh config set MY-PROJECT --provider ollama

# Deploy and start:
./oc.sh deploy all MY-PROJECT
./oc.sh start MY-PROJECT
```

## Security

- **API Keys**: All API keys are stored in local files (`.gitignore`d) and never committed to git.
- **Masking**: When viewing configurations, API keys are masked to show only the first 8 characters.
- **Environment-specific**: Each environment can have different provider configurations.

### Fichiers avec secrets

Les fichiers suivants contiennent des credentials et ne sont **jamais commités dans git** :

| Fichier | Pourquoi gitignored |
|---------|---------------------|
| `config/hub.json` | Contient l'`api_key` / bearer token — toujours gitignored |
| `opencode.json` | Généré par `adapter_deploy`, reflète la config provider locale — toujours gitignored |
| `projects/api-keys.local.md` | Clés API par projet — toujours gitignored par conception |

Un template sans secret est commité dans `config/hub.json.example`. Au premier lancement (ou après un clone), `hub.json` est créé automatiquement depuis ce template s'il n'existe pas.

```bash
# Après un clone, lancez cette commande pour configurer votre provider :
./oc.sh provider set-default
```

## Troubleshooting

### "Provider not supported"

If you see this error, ensure you're using one of the 5 supported providers:
- `anthropic`
- `mammouth`
- `github-models`
- `bedrock`
- `ollama`

### Claude Code shows "provider not supported" warning

This is expected. Claude Code only supports Anthropic. If you need to use Claude Code:
1. Configure an Anthropic API key at the hub level, or
2. Override your project to use `anthropic` provider

### Model not found / API errors

1. Verify your API key is correct: `./oc.sh provider get <PROJECT_ID>`
2. Check the base URL is correct for your provider
3. Ensure the provider service is running (especially for Ollama)
4. Test your API key directly with the provider's CLI or API

### Les changements de provider ne sont pas appliqués

Après `oc provider set-default`, `opencode.json` est automatiquement régénéré — aucune étape manuelle nécessaire.

Pour les changements au niveau projet (`oc config set` ou `oc provider set`), redéployez :

```bash
./oc.sh deploy all MON-PROJET
```

## Related Commands

- `./oc.sh config set` — Manage project-level provider and model configuration
- `./oc.sh config get` — View effective configuration for a project
- `./oc.sh deploy all` — Deploy agents with current provider config
- `./oc.sh start` — Start OpenCode with the configured provider
- `./oc.sh init` — Set up a new project (includes provider step)
