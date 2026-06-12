import type { Plugin } from "@opencode-ai/plugin"

// Context-Mode OpenCode Plugin
//
// Réduit la consommation de tokens sur trois axes complémentaires à RTK :
//
//   1. Sandbox tools  — les résultats volumineux de read/webfetch/MCP sont indexés
//      hors-contexte (SQLite + BM25) plutôt que injectés en entier. RTK couvre bash ;
//      context-mode couvre les outils natifs OpenCode que RTK ne touche pas.
//
//   2. Session continuity — chaque événement est stocké en SQLite. Après une compaction
//      automatique, l'agent retrouve l'état via BM25 plutôt que de tout re-injecter.
//
//   3. Think in Code — pousse l'agent à écrire un script d'analyse plutôt que de
//      chaîner 10 tool calls read/glob/grep pour la même information.
//
// Hooks OpenCode utilisés :
//   - tool.execute.before / tool.execute.after  (stables)
//   - experimental.chat.system.transform        (injecte les instructions en system prompt)
//   - experimental.session.compacting           (session continuity après compaction)
//
// Prérequis : Node >= 22.5, package npm `context-mode` installé globalement.
//
// Installation :
//   oc plugin install context-mode
//
// Version: 1.0.0 (2026-06-12)
// Compatible avec: context-mode npm ^1.0.0, OpenCode 1.15.0+

export const ContextModeOpenCodePlugin: Plugin = async ({ $, client }) => {
  // ─────────────────────────────────────────────────────────────────────────
  // Initialisation — vérifier que le package npm est disponible
  // ─────────────────────────────────────────────────────────────────────────

  let contextModeAvailable = false

  try {
    await $`node -e "require('context-mode')"`.quiet()
    contextModeAvailable = true
  } catch {
    // Tentative via npx (package installé localement ou dans le PATH npm global)
    try {
      await $`npx --yes context-mode --version`.quiet()
      contextModeAvailable = true
    } catch {
      console.warn("[context-mode-plugin] Package npm 'context-mode' introuvable — plugin désactivé")
      console.warn("[context-mode-plugin] Installer avec : npm install -g context-mode")
      console.warn("[context-mode-plugin] Ou via le hub  : oc plugin install context-mode")
      return {}
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Chargement du plugin amont (délégation au package npm)
  // ─────────────────────────────────────────────────────────────────────────

  let upstreamPlugin: Awaited<ReturnType<Plugin>> = {}

  try {
    // Import dynamique du plugin npm — il exporte un Plugin compatible OpenCode
    const mod = await import("context-mode")
    const upstream: Plugin = mod.default ?? mod.ContextModePlugin ?? mod.plugin

    if (typeof upstream === "function") {
      upstreamPlugin = await upstream({ $, client })
    } else {
      console.warn("[context-mode-plugin] Le package 'context-mode' n'exporte pas de Plugin valide — fonctionnement en mode dégradé")
    }
  } catch (err) {
    console.warn("[context-mode-plugin] Impossible de charger le plugin npm context-mode :", String(err))
    console.warn("[context-mode-plugin] Fonctionnement en mode dégradé (hooks de base uniquement)")
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Session state
  // ─────────────────────────────────────────────────────────────────────────

  let sessionStarted = false
  let sandboxedToolCalls = 0
  let estimatedTokensSaved = 0

  const initSession = async () => {
    if (sessionStarted) return
    sessionStarted = true

    await client.app.log({
      body: {
        service: "context-mode-plugin",
        level: "info",
        message: "Context-mode plugin initialized",
        extra: {
          upstream_loaded: Object.keys(upstreamPlugin).length > 0,
          available_hooks: Object.keys(upstreamPlugin),
        },
      },
    })
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Hook : Before Tool Execution
  // Délègue au plugin amont + tracking de session
  // ─────────────────────────────────────────────────────────────────────────

  const beforeHook: NonNullable<Awaited<ReturnType<Plugin>>["tool.execute.before"]> = async (input, output) => {
    await initSession()

    const tool = String(input?.tool ?? "").toLowerCase()

    // Tracking des outils sandboxés (read, webfetch, MCP calls)
    if (tool === "read" || tool === "webfetch" || tool === "websearch") {
      sandboxedToolCalls++

      await client.app.log({
        body: {
          service: "context-mode-plugin",
          level: "debug",
          message: `Tool intercepted by context-mode sandbox: ${tool}`,
          extra: {
            tool,
            session_sandboxed_calls: sandboxedToolCalls,
          },
        },
      })
    }

    // Déléguer au plugin amont s'il a un hook before
    if (typeof upstreamPlugin["tool.execute.before"] === "function") {
      return upstreamPlugin["tool.execute.before"](input, output)
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Hook : After Tool Execution
  // Estime les tokens économisés sur les gros outputs
  // ─────────────────────────────────────────────────────────────────────────

  const afterHook: NonNullable<Awaited<ReturnType<Plugin>>["tool.execute.after"]> = async (input, output) => {
    const out = output as Record<string, unknown> | undefined
    const tool = String(input?.tool ?? "").toLowerCase()

    // Estimer les tokens économisés sur les outputs volumineux
    if (tool === "read" || tool === "webfetch") {
      const rawOutput = String(out?.["output"] ?? "")
      const outputChars = rawOutput.length
      // Heuristique : ~4 chars/token, context-mode garde ~5% en contexte
      const rawTokens = Math.floor(outputChars / 4)
      const estimatedSaving = Math.floor(rawTokens * 0.90)

      if (estimatedSaving > 1000) {
        estimatedTokensSaved += estimatedSaving

        if (estimatedSaving > 10000) {
          await client.tui.toast({
            body: {
              type: "info",
              message: `🗜️ context-mode sandboxed ~${(estimatedSaving / 1000).toFixed(1)}K tokens (${tool})`,
            },
          })
        }

        await client.app.log({
          body: {
            service: "context-mode-plugin",
            level: "info",
            message: "Output sandboxed by context-mode",
            extra: {
              tool,
              raw_tokens_estimate: rawTokens,
              estimated_saving: estimatedSaving,
              session_total_saved: estimatedTokensSaved,
            },
          },
        })
      }
    }

    // Déléguer au plugin amont s'il a un hook after
    if (typeof upstreamPlugin["tool.execute.after"] === "function") {
      return upstreamPlugin["tool.execute.after"](input, output)
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Hook : Dispose (résumé de session)
  // ─────────────────────────────────────────────────────────────────────────

  const disposeHook: NonNullable<Awaited<ReturnType<Plugin>>["dispose"]> = async () => {
    if (!sessionStarted) return

    if (sandboxedToolCalls > 0) {
      await client.tui.toast({
        body: {
          type: "success",
          message: `🗜️ context-mode: ${sandboxedToolCalls} tools sandboxed, ~${(estimatedTokensSaved / 1000).toFixed(1)}K tokens économisés`,
        },
      })

      await client.app.log({
        body: {
          service: "context-mode-plugin",
          level: "info",
          message: "Context-mode session summary",
          extra: {
            sandboxed_tool_calls: sandboxedToolCalls,
            estimated_tokens_saved: estimatedTokensSaved,
          },
        },
      })
    }

    // Déléguer au plugin amont s'il a un hook dispose
    if (typeof upstreamPlugin["dispose"] === "function") {
      return upstreamPlugin["dispose"]()
    }

    // Reset
    sessionStarted = false
    sandboxedToolCalls = 0
    estimatedTokensSaved = 0
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Hooks expérimentaux — délégation au plugin amont
  //
  // experimental.chat.system.transform : injecte les instructions context-mode
  //   dans le system prompt de chaque session → pas besoin d'AGENTS.md global
  //
  // experimental.session.compacting : session continuity après compaction
  //   → l'agent retrouve l'état via BM25 plutôt que de tout re-injecter
  //
  // Ces hooks sont expérimentaux et susceptibles de changer lors des mises à jour
  // d'OpenCode. Si le plugin amont n'exporte pas ces hooks, ils sont silencieusement
  // ignorés — le plugin fonctionne en mode dégradé avec les hooks stables uniquement.
  // ─────────────────────────────────────────────────────────────────────────

  const experimentalHooks: Record<string, unknown> = {}

  if (typeof upstreamPlugin["experimental.chat.system.transform"] === "function") {
    experimentalHooks["experimental.chat.system.transform"] = upstreamPlugin["experimental.chat.system.transform"]
  }

  if (typeof upstreamPlugin["experimental.session.compacting"] === "function") {
    experimentalHooks["experimental.session.compacting"] = upstreamPlugin["experimental.session.compacting"]
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Export des hooks
  // ─────────────────────────────────────────────────────────────────────────

  return {
    "tool.execute.before": beforeHook,
    "tool.execute.after": afterHook,
    "dispose": disposeHook,
    ...experimentalHooks,
  }
}
