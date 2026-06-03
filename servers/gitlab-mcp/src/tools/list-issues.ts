/**
 * Tool: list_gitlab_issues
 * Liste les tickets d'un projet GitLab avec filtres optionnels.
 */

import type { GitLabClient } from '../client.js';
import { classifyGitlabError } from '../client.js';

export const listIssuesTool = {
  name: 'list_gitlab_issues',
  description:
    'List issues (tickets) for a GitLab project. Supports filtering by state, labels, and keyword search. ' +
    'Use this to discover relevant tickets before diving into a specific one with get_gitlab_issue.',
  inputSchema: {
    type: 'object',
    properties: {
      project_path: {
        type: 'string',
        description:
          'The project namespace and name, e.g. "my-group/my-project".',
      },
      state: {
        type: 'string',
        enum: ['opened', 'closed', 'all'],
        description: 'Filter by issue state. Defaults to "opened".',
      },
      labels: {
        type: 'string',
        description:
          'Comma-separated list of label names to filter by, e.g. "bug,priority::high".',
      },
      search: {
        type: 'string',
        description: 'Search keyword to filter issues by title and description.',
      },
      per_page: {
        type: 'number',
        description: 'Number of results to return (1–100). Defaults to 20.',
      },
      page: {
        type: 'number',
        description: 'Page number for pagination. Defaults to 1.',
      },
    },
    required: ['project_path'],
  },
};

export async function listIssues(
  client: GitLabClient,
  projectPath: string,
  options: {
    state?: 'opened' | 'closed' | 'all';
    labels?: string;
    search?: string;
    per_page?: number;
    page?: number;
  }
): Promise<{ content: Array<{ type: string; text: string }> }> {
  try {
    const params = {
      state: options.state ?? 'opened',
      ...(options.labels ? { labels: options.labels } : {}),
      ...(options.search ? { search: options.search } : {}),
      per_page: Math.min(Math.max(options.per_page ?? 20, 1), 100),
      page: options.page ?? 1,
    };

    const issues = await client.listIssues(projectPath, params);

    if (issues.length === 0) {
      return {
        content: [
          {
            type: 'text',
            text: `No issues found in ${projectPath} matching the given filters.`,
          },
        ],
      };
    }

    const filters: string[] = [];
    if (params.state !== 'all') filters.push(`state: ${params.state}`);
    if (options.labels) filters.push(`labels: ${options.labels}`);
    if (options.search) filters.push(`search: "${options.search}"`);
    const filterStr =
      filters.length > 0 ? ` (${filters.join(' | ')})` : '';

    const rows = issues.map((issue) => {
      const labels =
        issue.labels.length > 0 ? ` [${issue.labels.join(', ')}]` : '';
      const assignees =
        issue.assignees.length > 0
          ? ` → @${issue.assignees.map((a) => a.username).join(', @')}`
          : '';
      const milestone = issue.milestone ? ` 🏁 ${issue.milestone.title}` : '';
      return `- **#${issue.iid}** ${issue.state === 'closed' ? '~~' : ''}${issue.title}${issue.state === 'closed' ? '~~' : ''}${labels}${assignees}${milestone}`;
    });

    const text = `# Issues in ${projectPath}${filterStr}

Found **${issues.length}** issue(s) (page ${params.page}):

${rows.join('\n')}

_Use \`get_gitlab_issue\` with a specific \`issue_iid\` to read the full details and comments._`;

    return { content: [{ type: 'text', text }] };
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error listing issues for ${projectPath}: ${classifyGitlabError(error)}`,
        },
      ],
    };
  }
}
