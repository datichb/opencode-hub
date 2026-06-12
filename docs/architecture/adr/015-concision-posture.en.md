> 🇫🇷 [Lire en français](015-concision-posture.fr.md)

# ADR-015 — Concision posture skill for internal agents

## Status

Accepted

## Context

The hub's internal agents (orchestrator, orchestrator-dev, planner, pathfinder, developer, qa-engineer, reviewer) produce verbose outputs that are not formal deliverables for the end user, but coordination exchanges. These outputs systematically contain:

- **Valueless intro phrases**: "Sure!", "I'm going to now...", "Here's what I found:"
- **Restatements of known context**: repetition of what the user just said or what is already established in the session
- **Redundant transitions between titled sections**: "Let's now move to the next section:" before a `##` heading
- **Closing formulas**: "Feel free to ask any other questions."

These patterns carry no information and unnecessarily lengthen responses. Over long sessions with several chained agents, this represents 30-40% of response token volume.

The caveman project (JuliusBrussee/caveman, 71k stars) validates this approach at scale: average 65% reduction in output tokens across 10 benchmarks (22-87% depending on task type) with 100% technical accuracy maintained. The research paper "Brevity Constraints Reverse Performance Hierarchies in Language Models" (arxiv, March 2026) confirms that constraining to brevity improves accuracy by 26 points on certain benchmarks.

However, caveman in `full` or `ultra` mode is too aggressive for a hub where some agents produce formal deliverables (audit reports, UX specs, diagnostic reports). A `lite` level — filler suppression only — is the right trade-off.

The decision is to create a custom `posture/concision-posture` skill rather than installing the caveman plugin as-is for three reasons:
1. **Per-agent control**: the skill is selectively injected into the relevant agents. The caveman plugin is global.
2. **Preserved formalism**: the `lite` level is precisely defined to not touch formal deliverables (handoff blocks, reports). caveman `full` mode does not make this distinction.
3. **No external dependency**: a Markdown skill has no npm/binary prerequisites. No additional update surface.

## Decision

Create the `skills/posture/concision-posture.md` skill in **Bucket A** with the `lite` level as default.

**`lite` level — suppresses only:**
- Valueless intro phrases ("Sure!", "I'm going to...", "Here is...")
- Known-context restatements already in the session
- Redundant transitions between titled sections
- Closing formulas ("Feel free to...", "I hope this...")

**Does not affect:**
- `## Return to orchestrator` / `## Question for orchestrator` blocks (functional contracts)
- Mandatory narrative recaps (planner, debugger, onboarder, auditor, designers)
- Review reports, QA reports, diagnostic reports
- Technical justifications, warnings, hypotheses

**Agents in scope (Bucket A):** orchestrator, orchestrator-dev, planner, pathfinder, developer, qa-engineer, reviewer

**Excluded agents:** auditor-*, documentarian, ux-designer, ui-designer, debugger — their outputs are formal deliverables whose verbosity is intentional

**Configuration**: key `token_optimization.output_verbosity` in `config/hub.json`. Value `"lite"` activates the skill (default). Value `"off"` disables the skill by removing `posture/concision-posture` from agent frontmatters.

## Consequences

### Positive

- **-30-40% output tokens on internal agents** (based on caveman benchmarks for the equivalent "lite" level). Concrete impact on long multi-agent sessions.
- **No information loss**: the `lite` level only removes syntactic noise, not technical content.
- **Preserved formalism**: formal deliverables (reports, specs, handoff blocks) are not impacted because the agents that produce them do not have this skill.
- **Configurable**: `output_verbosity: "off"` in `hub.json` disables the skill on all agents without modifying individual frontmatters.
- **No dependency**: a Markdown file in `skills/posture/`, zero setup.

### Negative / trade-offs

- **Over-concision risk**: if an agent interprets "lite" too aggressively, useful information could be omitted. The skill is written with explicit examples of what should and should not be suppressed to minimize this risk.
- **Manual maintenance**: unlike the caveman plugin which evolves automatically, this skill must be manually updated if verbose patterns evolve with models.

## Rejected Alternatives

**caveman plugin as-is**: caveman in `full` mode does not distinguish coordination exchanges from formal deliverables. Risk of degraded audit reports or UX specs. No per-agent control. Additional npm dependency.

**Concision rules in each agent separately**: each agent would have its own version of the rules. Content duplication, distributed maintenance, risk of inconsistency between agents. A centralized skill is easier to maintain.

**Do nothing**: output tokens represent 40-60% of total cost on long multi-agent sessions. Filler is an observable and measurable pattern. The benefit/risk ratio of a `lite` skill is clearly favorable.

## Impact

| File | Action |
|------|--------|
| `skills/posture/concision-posture.md` | Created — Bucket A skill |
| `config/hub.json` | Modified — added `token_optimization.output_verbosity: "lite"` |
| `agents/planning/orchestrator.md` | Modified — `posture/concision-posture` added in `skills:` |
| `agents/planning/orchestrator-dev.md` | Modified — same |
| `agents/planning/planner.md` | Modified — same |
| `agents/planning/pathfinder.md` | Modified — same |
| `agents/developer/developer.md` | Modified — same |
| `agents/quality/qa-engineer.md` | Modified — same |
| `agents/quality/reviewer.md` | Modified — same |
