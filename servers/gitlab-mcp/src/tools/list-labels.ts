/**
 * Tool: list_gitlab_labels
 * Liste tous les labels d'un projet GitLab pour comprendre la taxonomie du projet.
 */

import type { GitLabClient } from '../client.js';
import { classifyGitlabError } from '../client.js';

export const listLabelsTool = {
  name: 'list_gitlab_labels',
  description:
    'List all labels defined in a GitLab project (including inherited group labels). ' +
    'Use this to understand the project\'s classification taxonomy before filtering issues or creating tickets.',
  inputSchema: {
    type: 'object',
    properties: {
      project_path: {
        type: 'string',
        description:
          'The project namespace and name, e.g. "my-group/my-project".',
      },
    },
    required: ['project_path'],
  },
};

export async function listLabels(
  client: GitLabClient,
  projectPath: string
): Promise<{ content: Array<{ type: string; text: string }> }> {
  try {
    const labels = await client.listLabels(projectPath, true);

    if (labels.length === 0) {
      return {
        content: [
          {
            type: 'text',
            text: `No labels found in ${projectPath}.`,
          },
        ],
      };
    }

    const rows = labels.map((label) => {
      const scope = label.is_project_label ? 'project' : 'group';
      const priority =
        label.priority !== null && label.priority !== undefined
          ? ` (priority: ${label.priority})`
          : '';
      const counts =
        label.open_issues_count !== undefined
          ? ` — ${label.open_issues_count} open issue(s), ${label.open_merge_requests_count ?? 0} open MR(s)`
          : '';
      const description = label.description
        ? `\n  _${label.description}_`
        : '';
      return `- **${label.name}**${priority} [${scope}]${counts}${description}`;
    });

    const text = `# Labels in ${projectPath}

Found **${labels.length}** label(s):

${rows.join('\n')}`;

    return { content: [{ type: 'text', text }] };
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error listing labels for ${projectPath}: ${classifyGitlabError(error)}`,
        },
      ],
    };
  }
}
