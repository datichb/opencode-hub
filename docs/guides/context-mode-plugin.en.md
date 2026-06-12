> 🇫🇷 [Lire en français](context-mode-plugin.fr.md)

# Context-mode Plugin Installation Guide

This guide explains how to install the context-mode plugin for OpenCode from opencode-hub.

## Prerequisites

1. **OpenCode** >= 1.15.0 installed
   ```bash
   opencode --version
   ```

2. **Node.js** >= 22.5.0 installed
   ```bash
   node --version
   brew install node  # If not installed
   brew upgrade node  # If version < 22.5.0
   ```

3. **opencode-hub** cloned and configured
   ```bash
   cd ~/.opencode-hub
   git pull
   ```

---

## Automatic Installation (Recommended)

```bash
oc plugin install context-mode
```

The script will:
1. Verify Node.js >= 22.5.0
2. Install the `context-mode` npm package globally if absent
3. Back up any existing plugin
4. Copy the plugin to `~/.config/opencode/plugins/context-mode.ts`

---

## Manual Installation

```bash
# Install the npm package
npm install -g context-mode

# Create the plugins directory if needed
mkdir -p ~/.config/opencode/plugins

# Copy the plugin
cp ~/.opencode-hub/plugins/context-mode/context-mode.ts ~/.config/opencode/plugins/context-mode.ts

# Verify
ls -lah ~/.config/opencode/plugins/context-mode.ts
```

---

## Verifying the Installation

### 1. Restart OpenCode

If OpenCode is running, close it and relaunch.

### 2. Check the Logs

```bash
tail -f ~/.cache/opencode/logs/opencode.log | grep context-mode-plugin
```

At session start, you should see:
```
service: "context-mode-plugin", level: "info", message: "Context-mode plugin initialized"
```

### 3. Test the Plugin

In OpenCode, open a large file or perform a webfetch:

```
> Read the file src/services/auth.service.ts
```

If the file exceeds ~4,000 tokens, a toast appears:
```
🗜️ context-mode sandboxed ~12.3K tokens (read)
```

### 4. Session Statistics

At session end (OpenCode close), a summary toast is shown:
```
🗜️ context-mode: 8 tools sandboxed, ~45.2K tokens saved
```

---

## What the Plugin Does

The plugin acts on three axes that are complementary to RTK:

| Axis | What RTK covers | What context-mode adds |
|------|----------------|----------------------|
| Bash outputs | ✅ `git diff`, `find`, `cat`, logs... | — |
| `read` / `webfetch` outputs | ❌ | ✅ Indexed out-of-context (SQLite + BM25) |
| MCP outputs | ❌ | ✅ Same |
| Session continuity | ❌ | ✅ Resume via BM25 after compaction |

### Sandbox Tools

When the agent reads a large file or performs a webfetch, context-mode intercepts the result and indexes it outside the LLM context. The agent can then query the index by semantic similarity — only the relevant passage enters the context.

**Measured impact:** 80-98% reduction on large outputs (files > 1K tokens, full web pages).

### Session Continuity

Each session event is stored in SQLite. If OpenCode automatically compacts the context, the agent recovers session state via BM25 without re-exploring the codebase.

**Measured impact:** 0 tokens wasted after compaction (vs. full codebase re-exploration).

### Think in Code

The plugin instructs the agent to write a targeted analysis script rather than chaining 10 `read`/`glob`/`grep` calls. One script replaces a multi-file exploration.

---

## OpenCode Hooks Used

| Hook | Stability | Role |
|------|-----------|------|
| `tool.execute.before` | Stable | Intercepts `read`, `webfetch` calls before execution |
| `tool.execute.after` | Stable | Estimates tokens saved on large outputs |
| `dispose` | Stable | Session summary (toast + log) |
| `experimental.chat.system.transform` | **Experimental** | Injects context-mode instructions into system prompt — no AGENTS.md required |
| `experimental.session.compacting` | **Experimental** | Session continuity after automatic compaction |

> **Note on experimental hooks:** The `experimental.*` hooks may change with OpenCode updates. The plugin operates in degraded mode (stable hooks only) if these hooks are absent or changed — the base sandbox remains active. Update the plugin after each major OpenCode update.

---

## Complementarity with RTK

RTK and context-mode are **orthogonal** — they cover different layers:

```
Bash command   → RTK intercepts → compressed output before injection
read/webfetch  → context-mode intercepts → output indexed out-of-context
```

Both plugins can coexist without conflict. Installation order does not matter.

**Recommended full stack:**
1. `oc plugin install rtk` — bash outputs (-60-90%)
2. `oc plugin install context-mode` — read/webfetch/MCP outputs (-80-98%) + session continuity

---

## Troubleshooting

### The `context-mode` npm package is not found at runtime

The plugin first tries `require('context-mode')`, then `npx --yes context-mode`. If both fail:

```bash
npm install -g context-mode
# Then restart OpenCode
```

### The `experimental.*` hooks are not active

If `experimental.chat.system.transform` is absent from your OpenCode version, the plugin operates in degraded mode: the base sandbox (tracking + token estimation) remains active, but context-mode instructions are not injected into the system prompt.

Check your OpenCode version:
```bash
opencode --version
```

If < 1.15.0, update: `npm install -g opencode-ai`

### Conflict with a `context-mode` MCP server

If you already have a `context-mode` MCP server installed, the OpenCode plugin takes precedence for system prompt injection but both coexist without functional conflict.

---

## Expected Metrics

| Output type | Estimated token reduction |
|-------------|--------------------------|
| Source file (>1K tokens) | 80-95% |
| Full webfetch page | 85-98% |
| Large MCP output | 70-90% |
| After compaction (session continuity) | 100% (0 tokens lost) |

---

## Updating

```bash
cd ~/.opencode-hub && git pull
oc plugin install context-mode  # Reinstalls from the updated hub version
```

## Uninstalling

```bash
rm ~/.config/opencode/plugins/context-mode.ts
npm uninstall -g context-mode  # Optional
```

---

**Version:** 1.0.0 (2026-06-12)
**Compatible with:** context-mode npm ^1.0.0, OpenCode >= 1.15.0, Node.js >= 22.5.0
