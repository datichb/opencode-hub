/**
 * Tool: get_gitlab_merge_request
 * Lit une Merge Request GitLab avec ses métadonnées complètes.
 */

import type { GitLabClient } from '../client.js';
import { classifyGitlabError } from '../client.js';

export const getMergeRequestTool = {
  name: 'get_gitlab_merge_request',
  description:
    'Read a GitLab Merge Request (MR) including its title, description, state, source/target branches, labels, assignees, reviewers and milestone. ' +
    'Use this to understand the scope and intent of a code change.',
  inputSchema: {
    type: 'object',
    properties: {
      project_path: {
        type: 'string',
        description:
          'The project namespace and name, e.g. "my-group/my-project".',
      },
      merge_request_iid: {
        type: 'number',
        description:
          'The merge request internal ID (the !N number shown in the GitLab UI).',
      },
    },
    required: ['project_path', 'merge_request_iid'],
  },
};

export async function getMergeRequest(
  client: GitLabClient,
  projectPath: string,
  mrIid: number
): Promise<{ content: Array<{ type: string; text: string }> }> {
  try {
    const mr = await client.getMergeRequest(projectPath, mrIid);

    const assignees =
      mr.assignees.length > 0
        ? mr.assignees.map((a) => `@${a.username}`).join(', ')
        : 'none';

    const reviewers =
      mr.reviewers.length > 0
        ? mr.reviewers.map((r) => `@${r.username}`).join(', ')
        : 'none';

    const milestone = mr.milestone
      ? `${mr.milestone.title}${mr.milestone.due_date ? ` (due: ${mr.milestone.due_date})` : ''}`
      : 'none';

    const labels = mr.labels.length > 0 ? mr.labels.join(', ') : 'none';

    const changesInfo =
      mr.changes_count !== null && mr.changes_count !== undefined
        ? `${mr.changes_count} file(s) changed`
        : 'unknown';

    const statusInfo: string[] = [];
    if (mr.draft) statusInfo.push('Draft');
    if (mr.has_conflicts) statusInfo.push('Has conflicts');
    if (mr.detailed_merge_status) statusInfo.push(mr.detailed_merge_status);

    const text = `# Merge Request !${mr.iid}: ${mr.title}

**Project:** ${projectPath}
**State:** ${mr.state}${statusInfo.length > 0 ? ` (${statusInfo.join(', ')})` : ''}
**Author:** @${mr.author.username}
**Assignees:** ${assignees}
**Reviewers:** ${reviewers}
**Labels:** ${labels}
**Milestone:** ${milestone}
**Source branch:** \`${mr.source_branch}\`
**Target branch:** \`${mr.target_branch}\`
**Changes:** ${changesInfo}
**Created:** ${mr.created_at}
**Updated:** ${mr.updated_at}${mr.merged_at ? `\n**Merged:** ${mr.merged_at}` : ''}${mr.closed_at ? `\n**Closed:** ${mr.closed_at}` : ''}
**URL:** ${mr.web_url}

---

## Description

${mr.description ? mr.description.trim() : '_No description._'}`;

    return { content: [{ type: 'text', text }] };
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error fetching merge request !${mrIid} from ${projectPath}: ${classifyGitlabError(error)}`,
        },
      ],
    };
  }
}
