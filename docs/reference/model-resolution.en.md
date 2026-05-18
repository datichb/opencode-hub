# Model resolution per agent

---

## Overview

Each agent can receive a specific AI model through a 7-level resolution cascade.
The first level that returns a value wins.

---

## Resolution cascade (7 levels)

For an agent `X` in family `F` within project `P`:

| Priority | Source | Key |
|----------|--------|-----|
| 1 | Project — specific agent | `api-keys.local.md` → `agent_models.agents.X=...` |
| 2 | Project — family | `api-keys.local.md` → `agent_models.families.F=...` |
| 3 | Project — global model | `api-keys.local.md` → `model=...` |
| 4 | Hub — specific agent | `config/hub.json` → `.agent_models.agents.X` |
| 5 | Hub — family | `config/hub.json` → `.agent_models.families.F` |
| 6 | Hub — global model | `config/hub.json` → `.opencode.model` |
| 7 | Hardcoded fallback | `claude-sonnet-4-5` |

**Example:** if the project defines a model for the `planning` family (level 2) and the hub defines a model for the `orchestrator` agent (level 4), level 2 wins because it has higher priority.

> **Note — provider prefixes:** provider prefixes (e.g. `anthropic/`) are optional in the resolution cascade. The hardcoded fallback (level 7) does not include one (`claude-sonnet-4-5`), while frontmatter or configuration values may include one (e.g. `anthropic/claude-opus-4`). Both forms are accepted.

> **Note — `default_provider.model`:** the `default_provider.model` field in `hub.json` is NOT used in this cascade. It only serves to configure the OpenCode provider, not for per-agent model resolution.

---

## Floor (clamp) via frontmatter

Agents can declare a minimum model via the `model:` field in their frontmatter:

```yaml
---
id: orchestrator
model: anthropic/claude-opus-4
---
```

After cascade resolution, if the resolved model is **lower** than the declared floor,
the floor is applied and a warning is emitted in the logs.

### Model hierarchy (for clamping)

```
claude-opus-4 > claude-sonnet-4-5 > claude-haiku-4-5
```

> **Note:** this list is non-exhaustive. Unlisted models are considered at the lowest rank (rank 0).

### Agents with a floor

| Agent | Floor |
|-------|-------|
| `orchestrator` | `anthropic/claude-opus-4` |
| `orchestrator-dev` | `anthropic/claude-opus-4` |
| `reviewer` | `anthropic/claude-opus-4` |
| `planner` | `anthropic/claude-opus-4` |

---

## Agent family

The family is inferred from the parent subfolder in `agents/`:

- `agents/planning/orchestrator.md` → family `planning`
- `agents/developer/developer-frontend.md` → family `developer`
- `agents/quality/reviewer.md` → family `quality`

---

## CLI configuration

```bash
# Hub level
oc config set --family-model planning=claude-opus-4
oc config set --agent-model debugger=claude-sonnet-4-5

# Project level
oc config set MY-APP --family-model planning=claude-opus-4
oc config set MY-APP --agent-model reviewer=claude-sonnet-4-5
```

---

## Injection rule in opencode.json

- If resolved model == project's global model → **no injection** (agent uses the default model)
- If resolved model ≠ global model → `"model": "<value>"` is injected into the agent's entry
