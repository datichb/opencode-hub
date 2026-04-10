> 🇫🇷 [Lire en français](skills.fr.md)

# Skills Reference

Skills are Markdown blocks injected into agents at deploy time.
They contain detailed protocols, output formats, checklists, and rules
that agents apply.

---

## Skill format

```markdown
---
name: <skill-name>
description: <Short description — visible in oc agent edit and oc skills list>
---

# Skill — <Title>

<Skill body>
```

> The `name` key is documentary. Hub scripts only read `description`.
> The file path is the reference used in agent frontmatter.

---

## Domain — `developer/`

Development standards skills. Shared between developer agents and the reviewer.

| File | Agents using it | Content |
|------|----------------|---------|
| `developer/beads-plan.md` | All developer-*, planner, onboarder, designers, documentarian | Reading and creating Beads tickets: `bd list`, `bd show`, `bd create`, `bd label list-all`, external links |
| `developer/beads-dev.md` | All developer-*, designers, documentarian | Beads executor workflow: `bd update --claim`, `bd close --suggest-next`, `ai-delegated` rules |
| `developer/dev-standards-universal.md` | All developer-*, reviewer | Clean Code, full SOLID, strict TypeScript, naming, structure |
| `developer/dev-standards-security.md` | All developer-*, reviewer | Secrets/config, input validation, injections (SQL/shell/LDAP), auth/authorization, logs without sensitive data, dependency auditing |
| `developer/dev-standards-backend.md` | developer-backend, developer-fullstack, developer-api, reviewer | Layered architecture, DTOs, services, repositories, API security |
| `developer/dev-standards-frontend.md` | developer-frontend, developer-fullstack, reviewer | Logic/presentation separation, performance, bundle, lazy loading |
| `developer/dev-standards-frontend-a11y.md` | developer-frontend, developer-fullstack, reviewer | WCAG 2.1 A/AA, semantic HTML, ARIA, contrast |
| `developer/dev-standards-vuejs.md` | developer-frontend, developer-fullstack | Composition API, `<script setup>`, Pinia, composables, Vue Router |
| `developer/dev-standards-testing.md` | developer-frontend, developer-backend, developer-fullstack, developer-api, developer-data, qa-engineer | Testing strategy, coverage, TDD, Vitest, pytest, PHPUnit |
| `developer/dev-standards-git.md` | All developer-*, reviewer | Conventional Commits, branches, PRs, commit messages |
| `developer/dev-standards-data.md` | developer-data | Data pipelines, ETL, ML, dbt, Airflow, data quality, dbt/Airflow/PySpark/ML tests |
| `developer/dev-standards-devops.md` | developer-devops | Docker, CI/CD, shell scripts (`set -euo pipefail`) |
| `developer/dev-standards-mobile.md` | developer-mobile | React Native, Flutter, Swift, Kotlin, mobile patterns, performance |
| `developer/dev-standards-platform.md` | developer-platform | Terraform, Pulumi, Kubernetes, Helm, GitOps (ArgoCD/Flux), secrets at scale (Vault, ESO) |
| `developer/dev-standards-api.md` | developer-api | API versioning, pagination, uniform response format, HTTP codes, idempotency, OpenAPI, breaking changes, webhooks, rate limiting |
| `developer/dev-standards-security-hardening.md` | developer-security | CORS, HTTP headers (CSP, HSTS, X-Frame-Options), bcrypt/argon2id, JWT (rotation, revocation), sessions (httpOnly/secure/sameSite), rate limiting, AES-256-GCM encryption |

---

## Domain — `auditor/`

Audit skills. All auditor-* agents inject `audit-protocol` + their domain skill.

| File | Agents using it | Content |
|------|----------------|---------|
| `auditor/audit-protocol.md` | auditor, all auditor-* | Common report format, 4 criticality levels (🔴/🟠/🟡/💡), /10 scoring, individual finding format |
| `auditor/audit-security.md` | auditor-security | OWASP Top 10, injections, exposed secrets, auth, CORS, CVE |
| `auditor/audit-performance.md` | auditor-performance | Core Web Vitals, LCP, CLS, TTI, N+1 queries, cache, bundle |
| `auditor/audit-accessibility.md` | auditor-accessibility | WCAG 2.1 AA, RGAA 4.1, semantics, ARIA, keyboard navigation, contrast |
| `auditor/audit-ecodesign.md` | auditor-ecodesign | RGESN, GreenIT, Écoindex, data transfer, resources, obsolescence |
| `auditor/audit-architecture.md` | auditor-architecture | SOLID, Clean Architecture, technical debt, coupling, cohesion |
| `auditor/audit-privacy.md` | auditor-privacy | GDPR articles 5/6/17/25/32, EDPB, CNIL, minimisation, consent |
| `auditor/audit-observability.md` | auditor-observability | RED method (Rate/Errors/Duration), structured logs, OpenTelemetry, SLOs/error budget, alerting (actionable, runbooks), dashboards, 5-question grid |

---

## Domain — `orchestrator/`

| File | Agents using it | Content |
|------|----------------|---------|
| `orchestrator/orchestrator-protocol.md` | orchestrator | Full feature workflow, routing matrix (3 families: design, auditor, dev via orchestrator-dev), checkpoint format ([CP-0], [CP-spec], [CP-audit], [CP-feature]), edge case handling |
| `orchestrator/orchestrator-dev-protocol.md` | orchestrator-dev | Beads ticket-by-ticket workflow, developer-* routing matrix (9 signals → 9 agents), checkpoint format ([CP-1] to [CP-3] + [CP-QA]), 3 modes (manual/semi-auto/auto), `tdd` label detection (CP-QA automatically skipped — tests written by the developer in red/green/refactor), step summary and global recap format |

---

## Domain — `qa/`

| File | Agents using it | Content |
|------|----------------|---------|
| `qa/qa-protocol.md` | qa-engineer | Test types (unit/integration/E2E/component), tools by stack, systematic checklist (nominal/error/edge cases/acceptance), coverage report format, AAA structure |

---

## Domain — `debugger/`

| File | Agents using it | Content |
|------|----------------|---------|
| `debugger/debug-protocol.md` | debugger | 4-step methodology, reading stacktraces and logs, diagnostic report format with graduated hypotheses, Beads ticket creation protocol |

---

## Domain — `reviewer/`

| File | Agents using it | Content |
|------|----------------|---------|
| `reviewer/review-protocol.md` | reviewer | Review report format (Critical/Major/Minor/Suggestion/Positive points/Out of scope), 4 severity levels, systematic 6-category checklist, individual comment format, "full audit" mode |

---

## Domain — `documentarian/`

Documentation skills. Used by the `documentarian` agent.

| File | Agents using it | Content |
|------|----------------|---------|
| `documentarian/doc-protocol.md` | documentarian | Mandatory exploration before writing, 4-situation adaptation table (compliant format / improvable / absent / partial), routing by doc type, gap checklist, Beads and direct workflow |
| `documentarian/doc-standards.md` | documentarian | Diataxis framework (4 quadrants), readability principles, type-specific structures (README, how-to, reference), common anti-patterns, quality criteria, functional documentation |
| `documentarian/doc-adr.md` | documentarian | Existing format detection (Nygard / MADR / Y-Statements / house), reference MADR format, naming rules, statuses (proposed/accepted/deprecated/superseded), creation criteria |
| `documentarian/doc-api.md` | documentarian | OpenAPI 3.x (skeleton, endpoint, reusable schemas), HTTP codes, narrative documentation (usage guide, pagination, error handling), breaking change identification and documentation |
| `documentarian/doc-changelog.md` | documentarian | Keep a Changelog (6 sections), SemVer (MAJOR/MINOR/PATCH), Conventional Commits → changelog sections, generation from git log, release workflow, extended release notes format |

---

## Domain — `planning/`

| File | Agents using it | Content |
|------|----------------|---------|
| `planning/planner.md` | planner | Phase 0 (codebase exploration + existing tickets + context summary), Phase 1 (contextualised questions + justified priority deduction), Phase 2 (hierarchical plan epics → tickets, >5 tickets rule), Phase 3 (creation with `--parent`, `--deps`, `--estimate`), Phase 4 (`bd children` verification), edge case handling (scope change, split, late dependency, duplicate) |
| `planning/project-discovery.md` | onboarder | Stack detection (manifests, CI, infra), adaptive exploration by profile (Vue, React, Node.js, Python, API, Data/ML, DevOps, Mobile), context report format (stack, architecture, patterns, 🔴/🟠/🟡, blind spots, questions, agent map), agent recommendation matrix (priority by risk + recommended by stack + optional), `projects.md` update protocol |

---

## Domain — `designer/`

Design skills. Used by the `ux-designer` and `ui-designer` agents.

| File | Agents using it | Content |
|------|----------------|---------|
| `designer/ux-protocol.md` | ux-designer | Nielsen heuristics (10 principles), 5-question UX grid, user flow format (nominal/alternatives/errors), UX spec format with acceptance criteria, friction audit protocol |
| `designer/ui-protocol.md` | ui-designer | Design tokens (colours, typography, spacing, radius, shadows), component spec format (variants/states/tokens/do-don't), visual consistency rules, inconsistency audit protocol, typographic modular scale |

---

## Domain — `posture/`

Cross-cutting posture skills. Injectable into any agent requiring an expert posture.

| File | Agents using it | Content |
|------|----------------|---------|
| `posture/expert-posture.md` | auditor, auditor-security, auditor-performance, auditor-accessibility, auditor-ecodesign, auditor-architecture, auditor-privacy, auditor-observability, onboarder, ux-designer, ui-designer, planner, documentarian | Systematic exploration before responding (announcing artefacts consulted, identifying uncertainty areas), argued counter-recommendation (⚠️ format with problem/alternative/why/trade-offs, first-person phrasing), confirmation pause before any high-risk action (🛑 format with explicit binary question) |

---

## Agent ↔ skills dependency matrix

```
orchestrator          → orchestrator/orchestrator-protocol
orchestrator-dev      → orchestrator/orchestrator-dev-protocol
onboarder             → planning/project-discovery, posture/expert-posture,
                         developer/beads-plan
planner               → developer/beads-plan, planning/planner, posture/expert-posture
reviewer              → dev-standards-universal, dev-standards-security,
                         dev-standards-backend,
                         dev-standards-frontend, dev-standards-frontend-a11y,
                         dev-standards-testing,
                         dev-standards-git, reviewer/review-protocol
qa-engineer           → dev-standards-universal, dev-standards-testing,
                         dev-standards-git, qa/qa-protocol
debugger              → debugger/debug-protocol
auditor               → auditor/audit-protocol, posture/expert-posture
auditor-security      → auditor/audit-protocol, auditor/audit-security, posture/expert-posture
auditor-performance   → auditor/audit-protocol, auditor/audit-performance, posture/expert-posture
auditor-accessibility → auditor/audit-protocol, auditor/audit-accessibility, posture/expert-posture
auditor-ecodesign     → auditor/audit-protocol, auditor/audit-ecodesign, posture/expert-posture
auditor-architecture  → auditor/audit-protocol, auditor/audit-architecture, posture/expert-posture
auditor-privacy       → auditor/audit-protocol, auditor/audit-privacy, posture/expert-posture
auditor-observability → auditor/audit-protocol, auditor/audit-observability, posture/expert-posture
ux-designer           → designer/ux-protocol, developer/beads-plan, developer/beads-dev, posture/expert-posture
ui-designer           → designer/ui-protocol, developer/beads-plan, developer/beads-dev, posture/expert-posture
developer-frontend    → dev-standards-universal, dev-standards-security,
                         dev-standards-frontend,
                         dev-standards-frontend-a11y, dev-standards-vuejs,
                         dev-standards-testing, dev-standards-git,
                         beads-plan, beads-dev
developer-backend     → dev-standards-universal, dev-standards-security,
                         dev-standards-backend,
                         dev-standards-testing, dev-standards-git,
                         beads-plan, beads-dev
developer-fullstack   → dev-standards-universal, dev-standards-security,
                         dev-standards-frontend,
                         dev-standards-frontend-a11y, dev-standards-vuejs,
                         dev-standards-backend, dev-standards-testing,
                         dev-standards-git, beads-plan, beads-dev
developer-data        → dev-standards-universal, dev-standards-security,
                         dev-standards-data, dev-standards-testing,
                         dev-standards-git, beads-plan, beads-dev
developer-devops      → dev-standards-universal, dev-standards-security,
                         dev-standards-devops,
                         dev-standards-git, beads-plan, beads-dev
developer-mobile      → dev-standards-universal, dev-standards-security,
                         dev-standards-mobile,
                         dev-standards-git, beads-plan, beads-dev
developer-api         → dev-standards-universal, dev-standards-security,
                         dev-standards-backend, dev-standards-api,
                         dev-standards-testing, dev-standards-git,
                         beads-plan, beads-dev
developer-platform    → dev-standards-universal, dev-standards-security,
                         dev-standards-platform,
                         dev-standards-git, beads-plan, beads-dev
developer-security    → dev-standards-universal, dev-standards-security,
                         dev-standards-security-hardening,
                         dev-standards-backend,
                         dev-standards-testing, dev-standards-git,
                         beads-plan, beads-dev
documentarian         → dev-standards-git, beads-plan, beads-dev,
                         documentarian/doc-protocol, documentarian/doc-standards,
                         documentarian/doc-adr, documentarian/doc-api,
                         documentarian/doc-changelog, posture/expert-posture
```
