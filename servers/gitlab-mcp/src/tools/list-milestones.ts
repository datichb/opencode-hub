/**
 * Tool: list_gitlab_milestones
 * Liste les milestones (sprints/releases) d'un projet GitLab.
 */

import type { GitLabClient } from '../client.js';
import { classifyGitlabError } from '../client.js';

export const listMilestonesTool = {
  name: 'list_gitlab_milestones',
  description:
    'List milestones (sprints or releases) for a GitLab project. ' +
    'Use this to understand the project\'s release cadence, identify the current sprint, or assess ticket urgency based on due dates.',
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
        enum: ['active', 'closed'],
        description:
          'Filter by milestone state. Omit to return all milestones. Use "active" to get only current/upcoming milestones.',
      },
    },
    required: ['project_path'],
  },
};

export async function listMilestones(
  client: GitLabClient,
  projectPath: string,
  state?: 'active' | 'closed'
): Promise<{ content: Array<{ type: string; text: string }> }> {
  try {
    const milestones = await client.listMilestones(projectPath, state);

    if (milestones.length === 0) {
      const stateStr = state ? ` with state "${state}"` : '';
      return {
        content: [
          {
            type: 'text',
            text: `No milestones found in ${projectPath}${stateStr}.`,
          },
        ],
      };
    }

    const rows = milestones.map((ms) => {
      const due = ms.due_date ? ` — due: ${ms.due_date}` : '';
      const start = ms.start_date ? ` (starts: ${ms.start_date})` : '';
      const expired = ms.expired ? ' ⚠️ EXPIRED' : '';
      const stateTag = ms.state === 'closed' ? ' [closed]' : ' [active]';
      const description = ms.description
        ? `\n  _${ms.description.trim().split('\n')[0]}_`
        : '';
      return `- **${ms.title}**${stateTag}${due}${start}${expired}${description}`;
    });

    const stateFilter = state ? ` (${state})` : '';
    const text = `# Milestones in ${projectPath}${stateFilter}

Found **${milestones.length}** milestone(s):

${rows.join('\n')}`;

    return { content: [{ type: 'text', text }] };
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error listing milestones for ${projectPath}: ${classifyGitlabError(error)}`,
        },
      ],
    };
  }
}
