# Agent Reference

27 agents in total, organized into 7 families.
Each agent is defined in `agents/<family>/<id>.md` with a frontmatter declaring its metadata,
targets, and skills.

---

## Agent Format

```markdown
---
id: <unique-identifier>
label: <DisplayedName>
description: <Short description — visible in AI tools>
mode: primary         # primary (default) | subagent
targets: [opencode, claude-code]
skills: [path/to/skill, ...]
---

# <Title>

<Agent body>
```

| Field | Role |
|-------|------|
| `id` | Unique identifier, used by adapters and `oc agent` |
| `label` | Name displayed in the target tool |
| `description` | Short phrase describing the role — appears in agent lists |
| `mode` | `primary` (default) or `subagent` — controls visibility in target tools |
| `targets` | Supported targets: `opencode`, `claude-code` |
| `skills` | Paths relative to `skills/` — injected in declaration order |

### Primary / Subagent Modes

The `mode:` field controls how an agent is exposed in each target tool:

| Mode | OpenCode | Claude Code |
|------|----------|-------------|
| `primary` | Visible in the Tab picker | Present in `.claude/agents/` |
| `subagent` | Listed in `opencode.json` with `"mode": "subagent"` — invocable by other agents, hidden in Tab picker | Present in `.claude/agents/` with delegation-oriented description |

The effective mode follows a priority: **project override** (`- Modes:` in `projects.md`) > **agent frontmatter** > **`primary`** (default).

To modify modes for a project without touching frontmatter: `oc agent mode <PROJECT_ID>`.

---

## Family — Coordinators

Agents that drive other agents without ever coding themselves.

### `onboarder`

| | |
|--|--|
| **Label** | Onboarder |
| **File** | `agents/planning/onboarder.md` |
| **Skills** | `planning/project-discovery`, `posture/expert-posture`, `developer/beads-plan` |
| **Invocation** | `"Onboard yourself on this project"` / `"Discover this project"` / `"Before starting, explore the project"` |

Project discovery agent. Explores an existing project's codebase and produces
a structured context report: detected stack, architecture, dominant patterns,
attention points (🔴/🟠/🟡), blind spots, clarification questions, and a
prioritized agent map (prioritized by detected risks, recommended by stack, optional).

Read-only — never modifies files (except `projects.md` on explicit confirmation
to enrich the `Stack` field). Never automatically triggers another agent — it suggests invocations, the user decides.

Invocable directly, from `oc start` (suggestion displayed), or from the `orchestrator`
(Mode C — pre-phase on unknown project).

---

### `orchestrator`

| | |
|--|--|
| **Label** | Orchestrator |
| **File** | `agents/planning/orchestrator.md` |
| **Skills** | `orchestrator/orchestrator-protocol` |
| **Invocation** | `"Implement [feature]"` / `"Handle tickets [IDs]"` |

AI project manager. Drives the complete delivery of a feature by mobilizing all
necessary agents: design (ux-designer, ui-designer), audit (auditor-*),
implementation (via orchestrator-dev). Enforces explicit checkpoints at each
phase. Never codes.

Two modes: **Mode A** (feature in natural language → delegates to planner) /
**Mode B** (existing Beads tickets → direct start).

Never routes directly to `developer-*` — always delegates to `orchestrator-dev`.

---

### `orchestrator-dev`

| | |
|--|--|
| **Label** | OrchestratorDev |
| **File** | `agents/planning/orchestrator-dev.md` |
| **Skills** | `orchestrator/orchestrator-dev-protocol` |
| **Invocation** | `"Implement tickets [IDs]"` / `"Dev workflow for [feature]"` |

AI tech lead specialized in driving implementation. Takes a list of ready-to-implement
Beads tickets, routes to the 9 `developer-*` agents, supervises optional QA and review.
Three modes: `manual` (default), `semi-auto`, `auto`. Invocable standalone or from the `orchestrator`.

CP-2 (merge or fix?) is always manual in all modes.

> See [ADR-006](./adr/006-orchestrator-configurable-mode.en.md) — modes apply to `orchestrator-dev` only.

---

### `auditor`

| | |
|--|--|
| **Label** | Auditor |
| **File** | `agents/auditor/auditor.md` |
| **Skills** | `auditor/audit-protocol` |
| **Invocation** | `"Audit [project/scope]"` / `"Audit [domain]"` |

Multi-domain audit coordinator. Qualifies the request (full / targeted / express audit)
and delegates to 7 specialized subagents. Produces a multi-domain executive summary.
Read-only — never modifies files.

---

## Family — Audit Agents

Auditor's subagents. All read-only. Invocable directly or via the auditor.

| Agent | File | Domain | References |
|-------|------|--------|-----------|
| `auditor-security` | `agents/auditor/auditor-security.md` | Application security | OWASP Top 10, CVE, RGS |
| `auditor-performance` | `agents/auditor/auditor-performance.md` | Web performance | Core Web Vitals, N+1, cache |
| `auditor-accessibility` | `agents/auditor/auditor-accessibility.md` | Accessibility | WCAG 2.1 AA, RGAA 4.1 |
| `auditor-ecodesign` | `agents/auditor/auditor-ecodesign.md` | Eco-design | RGESN, GreenIT, Écoindex |
| `auditor-architecture` | `agents/auditor/auditor-architecture.md` | Architecture & debt | SOLID, Clean Architecture |
| `auditor-privacy` | `agents/auditor/auditor-privacy.md` | Data protection | GDPR, EDPB, CNIL |
| `auditor-observability` | `agents/auditor/auditor-observability.md` | Observability | RED method, SLOs, OpenTelemetry, alerting |

All audit agents inject `auditor/audit-protocol` (common report format)
+ their domain-specific skill (`auditor/audit-<domain>`).

---

## Family — Developer Agents

9 agents specialized by technical domain. All follow the same Beads workflow
(`bd claim → implement → test → bd close`).

Common skills for all: `dev-standards-universal`, `dev-standards-security`, `dev-standards-git`, `beads-plan`, `beads-dev`.

| Agent | File | Domain | Specific Skills |
|-------|------|--------|----------------|
| `developer-frontend` | `agents/developer/developer-frontend.md` | UI, components, Vue.js, CSS, a11y | `dev-standards-frontend`, `dev-standards-frontend-a11y`, `dev-standards-vuejs`, `dev-standards-testing` |
| `developer-backend` | `agents/developer/developer-backend.md` | Services, repositories, migrations | `dev-standards-backend`, `dev-standards-testing` |
| `developer-fullstack` | `agents/developer/developer-fullstack.md` | Full-stack features | `dev-standards-frontend`, `dev-standards-backend`, `dev-standards-testing` |
| `developer-data` | `agents/developer/developer-data.md` | Pipelines, ETL, ML, dbt | `dev-standards-data` |
| `developer-devops` | `agents/developer/developer-devops.md` | Docker, CI/CD, shell scripts | `dev-standards-devops` |
| `developer-mobile` | `agents/developer/developer-mobile.md` | React Native, Flutter, iOS, Android | `dev-standards-mobile` |
| `developer-api` | `agents/developer/developer-api.md` | REST, GraphQL, webhooks | `dev-standards-backend`, `dev-standards-api`, `dev-standards-testing` |
| `developer-platform` | `agents/developer/developer-platform.md` | Terraform, K8s, Helm, GitOps, infra as code | `dev-standards-platform` |
| `developer-security` | `agents/developer/developer-security.md` | Application hardening post-audit | `dev-standards-security-hardening`, `dev-standards-backend`, `dev-standards-testing` |

> See [ADR-002](./adr/002-developer-segmentation.en.md) for the segmentation decision.

`developer-platform` differs from `developer-devops`: DevOps covers Dockerfile,
docker-compose, GitHub Actions and application shell scripts; Platform covers
Terraform/Pulumi, Kubernetes manifests, Helm charts, ArgoCD/Flux.

`developer-security` differs from `developer-backend`: it intervenes
exclusively after an `auditor-security` audit to fix identified vulnerabilities
(HTTP headers, CORS, hashing, JWT, sessions, rate limiting, encryption). It does not
perform audits.

---

## Family — Design Agents

UX/UI design agents. Work upstream of implementation.
Never code. Invocable directly or via the `orchestrator`.

### `ux-designer`

| | |
|--|--|
| **Label** | UXDesigner |
| **File** | `agents/design/ux-designer.md` |
| **Skills** | `designer/ux-protocol`, `developer/beads-plan`, `developer/beads-dev` |
| **Invocation** | `"Analyze the flow for [feature]"` / `"UX spec for [ticket]"` / `"UX audit of [screen]"` |

User experience expert. Analyzes needs, identifies friction, produces textual user flows
and actionable UX specifications with acceptance criteria. Asks at least 2 context
questions before specifying. Reads and closes Beads tickets. Does not produce graphic mockups.

---

### `ui-designer`

| | |
|--|--|
| **Label** | UIDesigner |
| **File** | `agents/design/ui-designer.md` |
| **Skills** | `designer/ui-protocol`, `developer/beads-plan`, `developer/beads-dev` |
| **Invocation** | `"UI spec for [component]"` / `"Design system [project]"` / `"Harmonize [screen]"` |

Interface design expert. Defines design system foundations (tokens),
specifies visual components with variants and states, produces actionable UI guidelines
for `developer-frontend`. Uses only tokens — never hard-coded values. Always proposes
options for art direction decisions.

---

## Family — Quality Agents

Agents dedicated to code quality, invocable standalone or via the orchestrator.

### `reviewer`

| | |
|--|--|
| **Label** | CodeReviewer |
| **File** | `agents/quality/reviewer.md` |
| **Skills** | `dev-standards-universal`, `dev-standards-security`, `dev-standards-backend`, `dev-standards-frontend`, `dev-standards-frontend-a11y`, `dev-standards-testing`, `dev-standards-git`, `reviewer/review-protocol` |
| **Invocation** | Pasted diff / branch name / PR URL + optionally `bd show <ID>` |

Analyzes PR/MR diffs. Produces a structured report by severity (Critical /
Major / Minor / Suggestion / Positive points). Read-only — never modifies files.

---

### `qa-engineer`

| | |
|--|--|
| **Label** | QAEngineer |
| **File** | `agents/quality/qa-engineer.md` |
| **Skills** | `dev-standards-universal`, `dev-standards-testing`, `dev-standards-git`, `qa/qa-protocol` |
| **Invocation** | `"Write tests for branch [X]"` / `"QA on ticket [ID]"` |

Writes missing tests (unit / integration / E2E) from a diff or a
Beads ticket. Produces a before/after coverage report. Never modifies functional code.

**Not relevant for TDD tickets**: when a ticket carries the `tdd` label,
tests are written by the developer themselves before implementation (red/green/refactor loop).
`orchestrator-dev` automatically skips CP-QA for these tickets — `qa-engineer` is not invoked.

> See [ADR-004](./adr/004-qa-debugger-separation.en.md).

---

### `debugger`

| | |
|--|--|
| **Label** | Debugger |
| **File** | `agents/quality/debugger.md` |
| **Skills** | `debugger/debug-protocol` |
| **Invocation** | `"This bug: [stacktrace]"` / `"Analyze these logs: [logs]"` |

Diagnoses the root cause of a bug in 4 steps (reproduction → isolation →
identification → hypothesis). Produces a diagnostic report with graded hypotheses.
Creates a Beads correction ticket after explicit confirmation.
Never fixes the bug.

> See [ADR-004](./adr/004-qa-debugger-separation.en.md).

---

## Family — Planning Agents

### `planner`

| | |
|--|--|
| **Label** | ProjectPlanner |
| **File** | `agents/planning/planner.md` |
| **Skills** | `developer/beads-plan`, `planning/planner`, `posture/expert-posture` |
| **Invocation** | Natural language feature description |

Functional and technical consultant who analyzes the project context before planning.
Explores the codebase (routes, models, components according to the feature's nature) and
existing Beads tickets, produces a context summary, asks contextualized questions,
then proposes a hierarchical plan (epics → tickets) with deduced and justified priorities.

Creates epics in Beads if > 5 tickets (asks otherwise), uses `--parent` and `--deps`
for hierarchy and dependencies. Handles contingencies: scope change, ticket splitting,
late dependency, duplicate. Never codes.

---

## Family — Documentation Agents

### `documentarian`

| | |
|--|--|
| **Label** | Documentarian |
| **File** | `agents/documentation/documentarian.md` |
| **Skills** | `developer/dev-standards-git`, `developer/beads-plan`, `developer/beads-dev`, `documentarian/doc-protocol`, `documentarian/doc-standards`, `documentarian/doc-adr`, `documentarian/doc-api`, `documentarian/doc-changelog`, `posture/expert-posture` |
| **Invocation** | `"Document [topic]"` / `"Create an ADR for [decision]"` / `"Update the CHANGELOG"` / `"What's missing in the docs?"` |

Writes and updates technical, functional, architectural documentation, API docs,
and changelogs. Systematically explores existing structure before writing.
Adapts to the format in place — recommends improvements without imposing them.
Never changes a format without explicit confirmation.

Guiding principle: **explore → adapt or propose → wait if needed → write**.

---

## Rules Common to All Agents

- **Read-only agents**: auditor-*, reviewer, debugger, ux-designer, ui-designer — never modify files
- **Agents that write code**: developer-*, qa-engineer — only modify files in their domain
- **Agents that write documentation**: documentarian — only modifies documentation files
- **Agents that create tickets**: planner (feature tickets), debugger (bug tickets after confirmation)
- **Agents that read tickets**: all can do `bd show <ID>` to contextualize their work
- **Coordinator agents**: orchestrator, orchestrator-dev, auditor — never code, drive other agents
- **Discovery agents**: onboarder — read-only, explores and reports, doesn't drive other agents
- **`primary` agents**: orchestrator, orchestrator-dev, planner, auditor, ui-designer, ux-designer, documentarian, onboarder, debugger, qa-engineer, reviewer — directly visible to the user
- **`subagent` agents**: all `developer-*` and `auditor-*` (except `auditor` itself) — invocable by coordinator agents
