/**
 * Configuration pour le MCP Server Figma
 */

export interface FigmaConfig {
  token: string;
  teamId: string;
  baseUrl: string;
  timeout: number;
  maxRetries: number;
}

export function getConfig(): FigmaConfig {
  const token = process.env.FIGMA_PERSONAL_ACCESS_TOKEN;
  const teamId = process.env.FIGMA_TEAM_ID;

  if (!token) {
    throw new Error(
      'FIGMA_PERSONAL_ACCESS_TOKEN environment variable is required. ' +
      'Configure it in ~/.config/opencode/config.json'
    );
  }

  if (!teamId) {
    throw new Error(
      'FIGMA_TEAM_ID environment variable is required. ' +
      'Configure it in ~/.config/opencode/config.json'
    );
  }

  const rawTimeout = parseInt(process.env.FIGMA_TIMEOUT || '30000', 10);
  const timeout = isNaN(rawTimeout) || rawTimeout <= 0 ? 30000 : rawTimeout;

  const rawRetries = parseInt(process.env.FIGMA_MAX_RETRIES || '2', 10);
  const maxRetries = isNaN(rawRetries) || rawRetries < 0 ? 2 : rawRetries;

  return {
    token,
    teamId,
    baseUrl: 'https://api.figma.com/v1',
    timeout,
    maxRetries,
  };
}
