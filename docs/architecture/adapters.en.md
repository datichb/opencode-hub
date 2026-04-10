# Adapters Architecture

An **adapter** translates canonical hub agents to the native format
of a target AI tool (opencode, claude-code, etc.).

---

## Mandatory Contract

Every adapter (`scripts/adapters/<target>.adapter.sh`) must export **6 functions**.
Loading is performed by `load_adapter()` in `scripts/lib/adapter-manager.sh`,
which verifies via `declare -F` that the 6 functions exist after the `source`.

| Function | Role | Signature |
|----------|------|-----------|
| `adapter_validate` | Checks that the target tool is installed and accessible | `adapter_validate()` — returns 0/1 |
| `adapter_needs_node` | Indicates whether Node.js is required for the tool | `adapter_needs_node()` — `return 0` (yes) or `return 1` (no) |
| `adapter_deploy` | Generates agent files in the target project | `adapter_deploy deploy_dir project_id` |
| `adapter_install` | Installs the target tool (called by `oc install`) | `adapter_install()` |
| `adapter_update` | Updates the target tool (called by `oc update`) | `adapter_update()` |
| `adapter_start` | Launches the tool in the project (called by `oc start`) | `adapter_start project_path prompt project_id` |

### Parameter Details

#### `adapter_deploy deploy_dir project_id`

- `deploy_dir`: path of the project directory to deploy into (e.g. `/home/user/my-project`)
- `project_id`: project identifier in `projects.md` (e.g. `MY-PROJECT`). Used to
  read the language (`get_project_language`) and API keys (`get_project_api_*`).

Responsibilities:
1. Create the output directory structure (e.g. `.opencode/agents/`, `.claude/agents/`)
2. Iterate over canonical agents in `CANONICAL_AGENTS_DIR`
3. Filter via `agent_supports_target` (only deploy compatible agents)
4. Call `build_agent_content` (from `prompt-builder.sh`) to assemble content
5. Write files in the format expected by the target tool

#### `adapter_start project_path prompt project_id`

- `project_path`: absolute path of the project directory
- `prompt`: initial prompt (may be empty)
- `project_id`: project identifier (for specific configuration)

---

## Available Utility Functions

An adapter has access to functions from `common.sh` and `prompt-builder.sh`:

| Function | Usage |
|----------|-------|
| `extract_frontmatter_value file key` | Reads a value from YAML frontmatter |
| `extract_frontmatter_list file key` | Parses an inline YAML list → one value per line |
| `strip_frontmatter file` | Returns the body without the frontmatter |
| `agent_supports_target file target` | Checks if an agent supports the target |
| `get_agent_id file` | Returns the `id` from the frontmatter |
| `get_agent_mode file` | Returns the `mode` from the frontmatter (`primary` by default) |
| `get_effective_agent_mode file project_id` | Effective mode: project override > frontmatter > `primary` |
| `build_agent_content file [target] [lang]` | Assembles complete content (header + skills + body) |
| `get_project_language project_id` | Returns the project language (or empty string) |
| `get_project_api_provider project_id` | Returns the API provider (anthropic, litellm, etc.) |
| `get_project_api_key project_id` | Returns the API key |
| `get_project_api_base_url project_id` | Returns the base URL (or empty string) |

---

## Creating a New Adapter

1. Create `scripts/adapters/<target>.adapter.sh` with the 6 functions
2. Add the target in `config/hub.json` (`active_targets` and `default_target` if relevant)
3. The file will be loaded automatically by `load_adapter` — no modification of
   `adapter-manager.sh` is needed
4. Test: `oc deploy <target>` then verify the generated files

### Minimal Example

```bash
#!/bin/bash
# scripts/adapters/my-tool.adapter.sh

adapter_validate() {
  command -v my-tool &>/dev/null || { log_error "my-tool not installed"; return 1; }
}

adapter_needs_node() { return 1; }

adapter_deploy() {
  local deploy_dir="${1:-$HUB_DIR}"
  local project_id="${2:-}"
  local out_dir="$deploy_dir/.my-tool/agents"
  mkdir -p "$out_dir"

  local lang=""
  [ -n "$project_id" ] && lang=$(get_project_language "$project_id")

  while IFS= read -r f; do
    [ -f "$f" ] || continue
    agent_supports_target "$f" "my-tool" || continue
    local agent_id; agent_id=$(get_agent_id "$f")
    local content; content=$(build_agent_content "$f" "$lang")
    printf '%s\n' "$content" > "$out_dir/${agent_id}.md"
  done < <(find "$CANONICAL_AGENTS_DIR" -name "*.md" | sort)
}

adapter_install() {
  log_info "Installing my-tool..."
  # ...
}

adapter_update() {
  log_info "Updating my-tool..."
  # ...
}

adapter_start() {
  local project_path="$1" prompt="${2:-}" project_id="${3:-}"
  cd "$project_path" || exit 1
  exec my-tool
}
```

---

## Existing Adapters

| Target | File | Node required | Specifics |
|--------|------|--------------|-----------|
| opencode | `opencode.adapter.sh` | Yes | Generates `opencode.json` (with `"agent":` block for subagents) + `.opencode/agents/*.md`, injects API keys |
| claude-code | `claude-code.adapter.sh` | Yes | Generates `.claude/agents/*.md` — subagents receive a prefixed description to guide Claude toward delegation |

### Mode Behavior by Target

| Agent mode | opencode | claude-code |
|-----------|----------|-------------|
| `primary` | Deployed normally, absent from the `"agent":` block | Deployed normally |
| `subagent` | Deployed normally, listed in `"agent": { "mode": "subagent" }` | Deployed with description prefixed `"Internal subagent — invoke only via a coordinator agent…"` |
