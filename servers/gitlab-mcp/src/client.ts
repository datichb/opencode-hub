/**
 * GitLab MCP Server
 * Client HTTP — wrapper axios avec retry/backoff
 */

import axios, { type AxiosInstance, type AxiosError } from 'axios';
import type { GitLabConfig } from './config.js';

// ---------------------------------------------------------------------------
// Types GitLab
// ---------------------------------------------------------------------------

export interface GitLabUser {
  id: number;
  username: string;
  name: string;
  state?: string;
}

export interface GitLabAuthor extends GitLabUser {
  avatar_url?: string;
  web_url?: string;
}

export interface GitLabMilestone {
  id: number;
  iid: number;
  title: string;
  description: string | null;
  state: 'active' | 'closed';
  due_date: string | null;
  start_date: string | null;
  expired?: boolean;
  web_url: string;
}

export interface GitLabIssue {
  id: number;
  iid: number;
  project_id: number;
  title: string;
  description: string | null;
  state: 'opened' | 'closed';
  labels: string[];
  assignees: GitLabUser[];
  author: GitLabAuthor;
  milestone: GitLabMilestone | null;
  created_at: string;
  updated_at: string;
  closed_at: string | null;
  due_date: string | null;
  web_url: string;
  user_notes_count: number;
  confidential: boolean;
  issue_type: string;
}

export interface GitLabNote {
  id: number;
  body: string;
  author: GitLabAuthor;
  created_at: string;
  updated_at: string;
  system: boolean;
  internal: boolean;
  resolvable: boolean;
}

export interface GitLabMergeRequest {
  id: number;
  iid: number;
  project_id: number;
  title: string;
  description: string | null;
  state: 'opened' | 'closed' | 'merged' | 'locked';
  source_branch: string;
  target_branch: string;
  labels: string[];
  assignees: GitLabUser[];
  reviewers: GitLabUser[];
  author: GitLabAuthor;
  milestone: GitLabMilestone | null;
  created_at: string;
  updated_at: string;
  merged_at: string | null;
  closed_at: string | null;
  web_url: string;
  changes_count: string | null;
  has_conflicts: boolean;
  detailed_merge_status: string;
  draft: boolean;
}

export interface GitLabLabel {
  id: number;
  name: string;
  description: string | null;
  color: string;
  priority: number | null;
  is_project_label: boolean;
  open_issues_count?: number;
  open_merge_requests_count?: number;
}

// ---------------------------------------------------------------------------
// Gestion des erreurs
// ---------------------------------------------------------------------------

const RETRYABLE_AXIOS_CODES = new Set([
  'ECONNABORTED',
  'ETIMEDOUT',
  'ERR_NETWORK',
  'ECONNRESET',
]);

const RETRYABLE_HTTP_STATUSES = new Set([429, 503, 504]);

export function classifyGitlabError(error: unknown): string {
  if (!axios.isAxiosError(error)) {
    return error instanceof Error ? error.message : 'Unknown error';
  }

  const axiosError = error as AxiosError;
  const status = axiosError.response?.status;

  if (status === 401) {
    return 'Authentication failed: invalid or expired GITLAB_PERSONAL_ACCESS_TOKEN.';
  }
  if (status === 403) {
    return 'Access forbidden: the token does not have the required scopes (api, read_user) or you lack access to this resource.';
  }
  if (status === 404) {
    return 'Resource not found: the project path or IID does not exist, or the token does not have access to it.';
  }
  if (status === 429) {
    return 'Rate limit exceeded: too many requests. Please try again in a few seconds.';
  }
  if (status === 503) {
    return 'GitLab service unavailable. Please try again shortly.';
  }

  if (axiosError.code === 'ECONNABORTED' || axiosError.code === 'ETIMEDOUT') {
    return 'Request timed out. The GitLab instance may be slow or unreachable.';
  }

  if (axiosError.message) {
    return `GitLab API error: ${axiosError.message}`;
  }

  return 'Unknown GitLab API error.';
}

async function withRetry<T>(
  fn: () => Promise<T>,
  maxRetries: number
): Promise<T> {
  let lastError: unknown;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;

      if (!axios.isAxiosError(error)) {
        throw error;
      }

      const axiosError = error as AxiosError;
      const status = axiosError.response?.status ?? 0;
      const code = axiosError.code ?? '';

      const isRetryable =
        RETRYABLE_HTTP_STATUSES.has(status) ||
        RETRYABLE_AXIOS_CODES.has(code);

      if (!isRetryable || attempt === maxRetries) {
        throw error;
      }

      const delay = 1000 * Math.pow(2, attempt);
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }

  throw lastError;
}

// ---------------------------------------------------------------------------
// Client GitLab
// ---------------------------------------------------------------------------

export class GitLabClient {
  private readonly http: AxiosInstance;
  private readonly maxRetries: number;

  constructor(config: GitLabConfig) {
    this.maxRetries = config.maxRetries;
    this.http = axios.create({
      baseURL: `${config.baseUrl}/api/v4`,
      timeout: config.timeout,
      headers: {
        'PRIVATE-TOKEN': config.token,
        'Content-Type': 'application/json',
      },
    });
  }

  // -------------------------------------------------------------------------
  // Issues
  // -------------------------------------------------------------------------

  async getIssue(projectPath: string, issueIid: number): Promise<GitLabIssue> {
    const encodedPath = encodeURIComponent(projectPath);
    return withRetry(
      () =>
        this.http
          .get<GitLabIssue>(`/projects/${encodedPath}/issues/${issueIid}`)
          .then((r) => r.data),
      this.maxRetries
    );
  }

  async getIssueNotes(
    projectPath: string,
    issueIid: number
  ): Promise<GitLabNote[]> {
    const encodedPath = encodeURIComponent(projectPath);
    return withRetry(
      () =>
        this.http
          .get<GitLabNote[]>(
            `/projects/${encodedPath}/issues/${issueIid}/notes`,
            {
              params: {
                activity_filter: 'only_comments',
                sort: 'asc',
                order_by: 'created_at',
                per_page: 100,
              },
            }
          )
          .then((r) => r.data),
      this.maxRetries
    );
  }

  async listIssues(
    projectPath: string,
    params: {
      state?: 'opened' | 'closed' | 'all';
      labels?: string;
      search?: string;
      per_page?: number;
      page?: number;
    }
  ): Promise<GitLabIssue[]> {
    const encodedPath = encodeURIComponent(projectPath);
    return withRetry(
      () =>
        this.http
          .get<GitLabIssue[]>(`/projects/${encodedPath}/issues`, { params })
          .then((r) => r.data),
      this.maxRetries
    );
  }

  // -------------------------------------------------------------------------
  // Merge Requests
  // -------------------------------------------------------------------------

  async getMergeRequest(
    projectPath: string,
    mrIid: number
  ): Promise<GitLabMergeRequest> {
    const encodedPath = encodeURIComponent(projectPath);
    return withRetry(
      () =>
        this.http
          .get<GitLabMergeRequest>(
            `/projects/${encodedPath}/merge_requests/${mrIid}`
          )
          .then((r) => r.data),
      this.maxRetries
    );
  }

  // -------------------------------------------------------------------------
  // Labels
  // -------------------------------------------------------------------------

  async listLabels(
    projectPath: string,
    withCounts = true
  ): Promise<GitLabLabel[]> {
    const encodedPath = encodeURIComponent(projectPath);
    return withRetry(
      () =>
        this.http
          .get<GitLabLabel[]>(`/projects/${encodedPath}/labels`, {
            params: {
              with_counts: withCounts,
              include_ancestor_groups: true,
              per_page: 100,
            },
          })
          .then((r) => r.data),
      this.maxRetries
    );
  }

  // -------------------------------------------------------------------------
  // Milestones
  // -------------------------------------------------------------------------

  async listMilestones(
    projectPath: string,
    state?: 'active' | 'closed'
  ): Promise<GitLabMilestone[]> {
    const encodedPath = encodeURIComponent(projectPath);
    const params: Record<string, unknown> = {
      per_page: 100,
      include_ancestors: true,
    };
    if (state) params.state = state;

    return withRetry(
      () =>
        this.http
          .get<GitLabMilestone[]>(`/projects/${encodedPath}/milestones`, {
            params,
          })
          .then((r) => r.data),
      this.maxRetries
    );
  }
}
