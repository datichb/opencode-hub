# MCP Servers

Ce dossier contient les MCP (Model Context Protocol) servers utilisés par les agents OpenCode.

## Structure

Chaque sous-dossier est un MCP server indépendant :

```
servers/
├── figma-mcp/           ← Intégration Figma (design, UI signals, tokens)
│   ├── src/
│   ├── dist/            ← Compilé (gitignored)
│   └── package.json
└── gitlab-mcp/          ← Intégration GitLab (issues, MRs, labels, milestones)
    ├── src/
    ├── dist/            ← Compilé (gitignored)
    └── package.json
```

## Développement

### Build un MCP

```bash
# Build tous les MCP
bash scripts/build-mcp.sh

# Build un seul MCP
bash scripts/build-mcp.sh figma-mcp
bash scripts/build-mcp.sh gitlab-mcp
```

### Tester un MCP localement

```bash
# Figma
cd servers/figma-mcp
npm install
npm run dev  # Mode watch

# Dans un autre terminal
FIGMA_PERSONAL_ACCESS_TOKEN=xxx npm start

# GitLab
cd servers/gitlab-mcp
npm install
npm run dev

# Dans un autre terminal
GITLAB_PERSONAL_ACCESS_TOKEN=glpat-xxx GITLAB_BASE_URL=https://gitlab.mycompany.com npm start
```

## Déploiement

Les MCP sont automatiquement déployés avec les agents :

```bash
oc deploy opencode MY-APP
```

Le script `deploy.sh` :
1. Vérifie l'état de build des MCP
2. Build automatiquement si nécessaire
3. Copie `dist/` + `package.json` dans `.opencode/servers/`
4. Installe les dépendances de production
5. Configure `opencode.json` du projet

## Configuration

Les tokens et variables d'environnement sont gérés via `oc service` :

```bash
oc service setup figma    # Configure Figma
oc service setup gitlab   # Configure GitLab
```

Ou manuellement dans `~/.config/opencode/config.json` :

```json
{
  "env": {
    "FIGMA_PERSONAL_ACCESS_TOKEN": "figd_xxx",
    "FIGMA_TEAM_ID": "123456",
    "GITLAB_PERSONAL_ACCESS_TOKEN": "glpat-xxx",
    "GITLAB_BASE_URL": "https://gitlab.mycompany.com"
  }
}
```

## Ajouter un nouveau MCP

1. Créer le dossier `servers/nouveau-mcp/`
2. Initialiser : `npm init` + installer `@modelcontextprotocol/sdk`
3. Implémenter `src/index.ts` (entry point MCP)
4. Ajouter le `case nouveau-mcp` dans `scripts/lib/mcp-deploy.sh` (fonction `configure_mcp_in_project`)
5. Déclarer le service dans `config/services.json`
6. Build : `bash scripts/build-mcp.sh nouveau-mcp`
7. Déployer : `oc deploy opencode MY-APP`
