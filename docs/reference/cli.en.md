> 🇫🇷 [Lire en français](cli.fr.md)

# CLI Reference — `oc` commands

All commands available via the `oc.sh` entry point (recommended alias: `oc`).

---

## Global synopsis

```
oc <command> [sub-command] [options] [arguments]
```

---

## `oc install`

Installs tools, creates the hub structure and configures active targets.

```bash
oc install
```

**Behaviour:**
- Interactive — presents a target selection menu
- Checks and **requests confirmation** before installing each dependency (Node.js, opencode, Beads, bun)
- If `config/hub.json` already exists, requests confirmation before overwriting

**Target options:**

| Choice | Targets configured |
|--------|--------------------|
| 1 (default) | OpenCode |
| 2 | Claude Code |
| 3 | All |

---

## `oc uninstall`

Uninstalls opencode-hub and cleans up artefacts created during installation.

```bash
oc uninstall
# equivalent to:
bash ~/.opencode-hub/uninstall.sh
```

**Behaviour:**

Guides the uninstallation through 4 optional steps, all with explicit confirmation:

| Step | Action | Default |
|------|--------|---------|
| 1 | Clean up deployed agents in projects (`.opencode/agents/`, `opencode.json`, `.claude/agents/`) | `[y/N]` |
| 2 | Remove the hub (`~/.opencode-hub`) | `[y/N]` |
| 3 | Remove the `oc` alias and bun exports from the shell rc file | `[Y/n]` |
| 4 | Uninstall system tools: `opencode`, `beads`, `bun` (separately) | `[y/N]` |

> `jq` and `node` are not offered for uninstallation (general use, risk of breaking other tools).
>
> A `.bak` backup is automatically created before any modification of the rc file.

---

## `oc deploy`

Generates agent files for a target in a project.

```bash
oc deploy <target> [PROJECT_ID]
oc deploy --check [target] [PROJECT_ID]
oc deploy --diff  [target] [PROJECT_ID]
```

**Arguments:**

| Argument | Values | Description |
|----------|--------|-------------|
| `<target>` | `opencode`, `claude-code`, `all` | Target to deploy |
| `[PROJECT_ID]` | ID of a registered project | Optional — deploys at hub level if absent |

**Options:**

| Option | Description |
|--------|-------------|
| `--check` | Checks if files are up to date without deploying |
| `--diff` | Compares sources with deployed files; offers deployment if a difference is detected |

**Examples:**

```bash
oc deploy opencode              # deploy OpenCode at hub level
oc deploy opencode MY-APP       # deploy OpenCode in MY-APP
oc deploy all MY-APP            # deploy all active targets in MY-APP
oc deploy --check               # check all active targets (hub)
oc deploy --check opencode      # check OpenCode (hub)
oc deploy --check all MY-APP    # check all targets for MY-APP
oc deploy --diff all MY-APP     # show diff sources → deployed for MY-APP
```

**Generated outputs:**

| Target | Generated files |
|--------|----------------|
| `opencode` | `.opencode/agents/*.md` + `opencode.json` (regenerated if an API key or PROJECT_ID is defined) |
| `claude-code` | `.claude/agents/*.md` |

**`--check` exit codes:**
- `0`: everything is up to date
- `1`: at least one file is outdated or missing

> An animated spinner (`⠋⠙⠹…`) is displayed while deploying each target.

---

## `oc sync`

Redeploys agents on all registered projects that have a defined local path.

```bash
oc sync [--dry-run]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--dry-run` | Checks freshness without deploying (equivalent to `oc deploy --check` on each project) |

**Examples:**

```bash
oc sync             # redeploy on all projects
oc sync --dry-run   # check without deploying
```

---

## `oc start`

Launches the default tool in a project's directory.

```bash
oc start [PROJECT_ID] [prompt] [--dev [--label <label>] [--assignee <user>]] [--onboard]
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `[PROJECT_ID]` | Project ID — interactive selection if absent |
| `[prompt]` | Startup prompt passed to the tool |

**Options:**

| Option | Description |
|--------|-------------|
| `--dev` | Development mode — loads open `ai-delegated` tickets into the startup prompt. Automatically performs a tracker sync `--pull-only` before launch. |
| `--dev --label <label>` | Like `--dev`, but filters tickets with label `<label>` |
| `--dev --assignee <user>` | Like `--dev`, but filters tickets assigned to `<user>` |
| `--onboard` | Injects a project discovery prompt to onboard the agent on the codebase |

> `--dev` and `--onboard` are mutually exclusive. `--label` and `--assignee` are mutually exclusive.

**Examples:**

```bash
oc start                                        # interactive project selection
oc start MY-APP                                 # launch tool in MY-APP
oc start MY-APP "explain the architecture"      # with startup prompt
oc start MY-APP --dev                           # load ai-delegated tickets
oc start MY-APP --dev --label ai-delegated      # filter by label
oc start MY-APP --dev --assignee alice          # filter by assignee
oc start MY-APP --onboard                       # project discovery prompt
```

**Launch display:**

```
◆  MY-APP
│  Path       /Users/alice/workspace/my-app
│  Target     opencode
│
│  → New to this project? Invoke the onboarder agent
│    "Onboard yourself onto this project"
│  → Or launch directly: ./oc.sh start --onboard MY-APP
│
└  Launching opencode…
```

> Warns in the context block if agents are not deployed (`◆` yellow) or if `.beads/` is absent.

---

## `oc audit`

Launches an AI audit on a project by invoking the `auditor` agent (and its specialised sub-agent if `--type` is specified).

```bash
oc audit [PROJECT_ID] [--type <type>]
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `[PROJECT_ID]` | Project ID — interactive selection if absent |

**Options:**

| Option | Values | Description |
|--------|--------|-------------|
| `--type <type>` | `security`, `accessibility`, `architecture`, `ecodesign`, `observability`, `performance`, `privacy` | Targets the audit on a specific domain. If absent: global audit via `auditor` |

**Behaviour:**

1. **Validation** — verifies the `--type` is among the 7 recognised domains (if provided)
2. **Project resolution** — normalises the ID and resolves the local path
3. **projects.md check** — if the project has a restrictive agent selection (not `all`), verifies that `auditor` (and `auditor-<type>` if specified) are included:
   - If missing → offers to add them + redeploy
   - If refused → displays physically deployed audit agents and offers a selection menu
4. **Physical deployment check** — if the agents folder is absent or files are missing, offers `oc deploy`
5. **Launch** — builds the bootstrap prompt and opens the tool with `--agent auditor` (or the selected agent)

**Examples:**

```bash
oc audit                          # interactive project selection, global audit
oc audit MY-APP                   # global audit on MY-APP
oc audit MY-APP --type security   # security audit only
oc audit MY-APP --type privacy    # GDPR/privacy audit only
```

**Injected prompt:**

```
Perform a complete audit of the project.

Project: MY-APP
Path: /Users/alice/workspace/my-app
Scope: security audit only.   ← present only if --type

Workflow:
1. Announce the audit scope and methodology
2. Explore relevant files according to the audit type
3. Identify and classify points of attention (🔴 critical, 🟠 important, 🟡 improvements)
4. Produce the structured audit report with prioritised recommendations
```

> For a complete multi-domain audit, invoke the `auditor` agent directly without `--type`.

---

## `oc conventions`

Generates or updates the `CONVENTIONS.md` file at the root of a project by
invoking the `onboarder` agent in conventions mode.

```bash
oc conventions [PROJECT_ID] [--force]
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `[PROJECT_ID]` | Project ID — interactive selection if absent |

**Options:**

| Option | Description |
|--------|-------------|
| `--force` | Overwrites `CONVENTIONS.md` without asking for confirmation if it already exists |

**Behaviour:**

1. Resolves the project (interactive if `PROJECT_ID` absent)
2. If `CONVENTIONS.md` already exists in the project → displays the generation date and requests confirmation before overwriting (unless `--force`)
3. Injects the conventions bootstrap prompt and opens the tool with the `onboarder` agent
4. The agent explores the codebase, detects real conventions (9 categories) and generates `CONVENTIONS.md`
5. Adds `CONVENTIONS.md` to the project's `.git/info/exclude` if not already there (local exclusion, invisible to other devs)

**Examples:**

```bash
oc conventions                   # interactive project selection
oc conventions MY-APP            # generate CONVENTIONS.md for MY-APP
oc conventions MY-APP --force    # regenerate without confirmation
```

**Generated file:**

`CONVENTIONS.md` documents real conventions observed in the codebase:
formatting, naming, architecture, tests, Git, error handling, security,
performance, and project-specific conventions. This file is read by all developer
and quality agents at the start of a session to code respecting the project's
conventions rather than generic standards.

> `CONVENTIONS.md` is excluded via `.git/info/exclude` — it stays local to the workstation, invisible to other devs.
> To regenerate it after a project evolution: `oc conventions MY-APP --force`.

---

## `oc init`

Registers a project in the hub. Guides the user through **5 numbered steps** and displays a coloured summary at the end.

```bash
oc init [PROJECT_ID] [path]
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `[PROJECT_ID]` | Unique project identifier (letters, digits, `-`, `_`) |
| `[path]` | Absolute or `~`-expanded path to the project directory |

**Interactive wizard:**

| Step | Content |
|------|---------|
| 1 — Project information | PROJECT_ID, path, directory verification/creation, name, stack, labels, tracker |
| 2 — Beads & tracker | `bd init`, Git upstream, tracker configuration |
| 3 — Agents & targets | Agent selection, deployment targets, and native OpenCode agents to disable |
| 4 — LLM provider | Project-specific provider configuration (overrides hub) |
| 5 — Deployment | Immediate deployment proposal |

> Directory creation happens at the **end of step 1** — Beads is thus guaranteed accessible from step 2.

**Wizard display:**

```
◆  Project initialisation
│
│
◇  Step 1/5 — Project information
│
│  PROJECT_ID (e.g. MY-APP):
│  ...
│
◇  Step 2/5 — Beads & tracker
│
│  ...
```

**Final summary:**

```
┌─ MY-APP initialised ──────────────────────────────┐
│  Path         /Users/alice/workspace/my-app        │
│  Name         My Application                       │
│  Stack        Vue 3 + Laravel                      │
│  Tracker      jira                                 │
│  Beads        ◆ initialised                        │
│                                                    │
│  Next → ./oc.sh start MY-APP                       │
└────────────────────────────────────────────────────┘

└  Project MY-APP ready — ./oc.sh start MY-APP
```

**Examples:**

```bash
oc init                              # full interactive mode
oc init MY-APP ~/workspace/my-app    # pre-fills ID and path (remaining questions interactive)
```

---

## `oc list`

Lists registered projects with their accessibility status.

```bash
oc list
```

> For a detailed dashboard (Beads, API, agents, tracker), use `oc status`.

---

## `oc status`

Displays a dashboard of the state of all registered projects.

```bash
oc status
```

**For each project, checks:**
- Local path accessible
- Beads initialised (`.beads/`)
- API key configured (provider + model)
- Tracker configured
- Agents deployed for the default target

**Example output:**

```
  MY-APP
    ·  Path: /Users/alice/workspace/my-app
    ✔  Beads initialised
    ✔  API configured (anthropic / claude-sonnet-4-5)
    ·  Tracker: none
    ✔  Agents deployed (opencode): 12 file(s)
```

---

## `oc remove`

Removes a project from the registry (with confirmation).

```bash
oc remove <PROJECT_ID> [--clean]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--clean` | Also removes deployed agent files in the project directory (`.opencode/agents/`, `opencode.json`, `.claude/agents/` depending on active targets) |

**Examples:**

```bash
oc remove MY-APP           # remove from registry only
oc remove MY-APP --clean   # remove from registry + clean deployed files
```

> Requests confirmation in both cases. Also removes the entry from `paths.local.md` and `api-keys.local.md`.

---

## `oc update`

Updates installed tools according to active targets.

```bash
oc update
```

---

## `oc upgrade`

Updates the hub sources themselves (`git pull` on the local repo). With an optional version argument, checks out a specific release tag.

```bash
oc upgrade              # pull latest main
oc upgrade v1.1.0       # checkout tag v1.1.0
```

After a successful update, offers to re-run `oc sync` to redeploy agents on all registered projects.

> Use `oc update` to update the installed tools (opencode, Beads, external skills). Use `oc upgrade` to update the hub scripts and agents themselves.

---

## `oc version`

Displays the hub version (read from `config/hub.json`).

```bash
oc version
```

---

## `oc config`

Manages API keys and AI models per project. Data is stored in `projects/api-keys.local.md` (not versioned).

```bash
oc config <sub-command> [options]
```

| Sub-command | Description |
|-------------|-------------|
| `set <PROJECT_ID> [options]` | Configure the API key, model and provider for a project |
| `get <PROJECT_ID>` | Display a project's configuration (masked key) |
| `list` | List all registered configurations |
| `unset <PROJECT_ID>` | Delete a project's configuration (with confirmation) |

**`oc config set` options:**

| Option | Description |
|--------|-------------|
| `--model <model>` | AI model (default: `claude-sonnet-4-5`) |
| `--provider <provider>` | `anthropic` or `litellm` (default: `anthropic`) |
| `--api-key <key>` | API key (masked input in interactive mode) |
| `--base-url <url>` | Base URL (litellm only) |

> Without options, `set` is interactive — offers current values as defaults.
> After a `set`, offers to re-deploy `opencode.json` in the project if the path is known.

**Examples:**

```bash
oc config set MY-APP                                 # interactive mode
oc config set MY-APP --model claude-opus-4-5 --provider anthropic --api-key sk-ant-...
oc config set MY-APP --provider litellm --api-key sk-... --base-url https://api.example.com/v1
oc config get MY-APP                                 # display config (masked key)
oc config list                                       # list all entries
oc config unset MY-APP                               # delete (with confirmation)
```

---

## `oc agent`

Manages the hub's canonical agents.

```bash
oc agent <sub-command>
```

| Sub-command | Description |
|-------------|-------------|
| `list` | List all agents with their id, label and targets |
| `create` | Create a new agent (interactive workflow) |
| `edit <id>` | Modify skills and metadata of an existing agent |
| `info <id>` | Display the full detail of an agent (frontmatter + body) |
| `select <PROJECT_ID>` | Choose which agents to deploy for a project |
| `mode <PROJECT_ID>` | Display / override `primary`/`subagent` modes per project |
| `validate [agent-id]` | Validate agent consistency (required fields, existing skills, valid targets, id uniqueness) |
| `keytest` | Keyboard diagnostic for the interactive selector |

### `oc agent create` — interactive workflow

1. **Identifier** — unique slug (e.g. `reviewer`)
2. **Label** — short name displayed in the tool (e.g. `CodeReviewer`)
3. **Description** — short phrase describing the role
4. **Targets** — interactive selector ↑↓/space: `opencode`, `claude-code`
5. **Skills** — interactive selector ↑↓/space with description panel
6. **Body** — if `opencode` is available, offer to auto-generate via `opencode run`
7. **Preview** — display of the complete `.md` file before writing
8. **Confirmation** — `Y/n` to create the file

### `oc agent validate`

```bash
oc agent validate             # validate all canonical agents
oc agent validate <agent-id>  # validate only the specified agent
```

Verifies for each agent:
- Required fields present (`id`, `label`, `description`, `targets`, `skills`)
- `id` uniqueness across all agents
- Valid `mode` (`primary` | `subagent` | `all`) if present
- All targets in `targets` recognised (`opencode`, `claude-code`)
- All referenced skills exist (local or external)

Returns exit code 1 if at least one error is detected.

> `oc agent keytest` displays raw bytes received for each key. Useful for
> diagnosing a terminal where selector navigation doesn't work. Quit with `q`.

> The interactive selector (agents, targets) uses the alternate screen (`smcup`/`rmcup`) — the parent terminal content is fully preserved on close.

---

## `oc skills`

Manages external skills downloaded via context7.

```bash
oc skills <sub-command>
```

| Sub-command | Description |
|-------------|-------------|
| `search <query>` | Search for available skills |
| `add /owner/repo [name]` | Add an external skill |
| `list` | List all skills (local + external) |
| `update [name]` | Update an external skill (or all if absent) |
| `info /owner/repo` | Preview available skills in a repository |
| `used-by <skill>` | List agents that use this skill |
| `sync` | Re-download all external skills (useful after clone) |
| `remove <name>` | Remove an external skill |

---

## `oc beads`

Manages the Beads (`bd`) integration in registered projects.

```bash
oc beads <sub-command>
```

| Sub-command | Description |
|-------------|-------------|
| `status [PROJECT_ID]` | Check Beads on all projects (or just one) |
| `init <PROJECT_ID>` | Initialise `.beads/` in the project |
| `list <PROJECT_ID>` | List open tickets in the project |
| `create <PROJECT_ID> [title] [--label <l>] [--type <t>] [--desc <d>]` | Create a ticket in the project |
| `open <PROJECT_ID>` | Display the path to use `bd` manually |
| `sync <PROJECT_ID> [options]` | Synchronise with an external tracker |
| `tracker status <PROJECT_ID>` | Display the tracker connection status |
| `tracker setup <PROJECT_ID>` | Configure the tracker (interactive) |
| `tracker switch <PROJECT_ID>` | Switch provider (jira ↔ gitlab ↔ none) |
| `tracker set-sync-mode <PROJECT_ID> [mode]` | Set default sync direction for the project |

### `oc beads create`

```bash
oc beads create <PROJECT_ID> [title] [--label <label>] [--type <type>] [--desc <description>]
```

| Argument / Option | Description |
|-------------------|-------------|
| `<PROJECT_ID>` | Project in which to create the ticket |
| `[title]` | Ticket title — interactive mode if absent |
| `--label <label>` | Ticket label |
| `--type <type>` | Ticket type (`feature`, `fix`, `chore`, …) |
| `--desc <description>` | Long description |

**Examples:**

```bash
oc beads create MY-APP                                              # interactive mode
oc beads create MY-APP "Add role management"                        # direct title
oc beads create MY-APP "Fix race condition" --type fix --label bug  # with flags
```

**`oc beads sync` options:**

| Option | Description |
|--------|-------------|
| `--pull-only` | Import only from the tracker (overrides the project `Sync mode`) |
| `--push-only` | Export only to the tracker (overrides the project `Sync mode`) |
| `--dry-run` | Simulate without modifying |

> The default direction of `oc beads sync` is controlled by the `Sync mode` field in `projects.md`
> (set with `oc beads tracker set-sync-mode <PROJECT_ID>`). Default value: `bidirectional`.
> A CLI flag always takes precedence over the configured mode.

> `oc start` automatically warns if `.beads/` is not present in the project.
