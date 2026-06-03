/**
 * GitLab MCP Server
 * Configuration — lecture des variables d'environnement
 */

export interface GitLabConfig {
  token: string;
  baseUrl: string;
  timeout: number;
  maxRetries: number;
}

export function getConfig(): GitLabConfig {
  const token = process.env.GITLAB_PERSONAL_ACCESS_TOKEN;
  if (!token) {
    throw new Error(
      'GITLAB_PERSONAL_ACCESS_TOKEN is required. ' +
      'Create a personal access token at <your-gitlab>/profile/personal_access_tokens with scopes: api, read_user'
    );
  }

  const baseUrl = (process.env.GITLAB_BASE_URL ?? 'https://gitlab.com').replace(/\/$/, '');

  const rawTimeout = parseInt(process.env.GITLAB_TIMEOUT ?? '30000', 10);
  const timeout = isNaN(rawTimeout) || rawTimeout <= 0 ? 30000 : rawTimeout;

  const rawRetries = parseInt(process.env.GITLAB_MAX_RETRIES ?? '2', 10);
  const maxRetries = isNaN(rawRetries) || rawRetries < 0 ? 2 : rawRetries;

  return { token, baseUrl, timeout, maxRetries };
}
