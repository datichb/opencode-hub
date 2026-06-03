/**
 * Tool: get_gitlab_issue
 * Lit un ticket GitLab (titre, description, métadonnées) ainsi que ses commentaires humains.
 */

import type { GitLabClient } from '../client.js';
import { classifyGitlabError } from '../client.js';

export const getIssueTool = {
  name: 'get_gitlab_issue',
  description:
    'Read a GitLab issue (ticket) including its title, description, state, labels, assignees, milestone and human comments. ' +
    'Use this to understand the full context of a ticket before planning or implementing.',
  inputSchema: {
    type: 'object',
    properties: {
      project_path: {
        type: 'string',
        description:
          'The project namespace and name, e.g. "my-group/my-project" or "my-group/sub-group/my-project".',
      },
      issue_iid: {
        type: 'number',
        description:
          'The issue internal ID (the #N number shown in the GitLab UI).',
      },
    },
    required: ['project_path', 'issue_iid'],
  },
};

export async function getIssue(
  client: GitLabClient,
  projectPath: string,
  issueIid: number
): Promise<{ content: Array<{ type: string; text: string }> }> {
  try {
    const [issue, notes] = await Promise.all([
      client.getIssue(projectPath, issueIid),
      client.getIssueNotes(projectPath, issueIid),
    ]);

    const assignees =
      issue.assignees.length > 0
        ? issue.assignees.map((a) => `@${a.username}`).join(', ')
        : 'none';

    const milestone = issue.milestone
      ? `${issue.milestone.title}${issue.milestone.due_date ? ` (due: ${issue.milestone.due_date})` : ''}`
      : 'none';

    const labels =
      issue.labels.length > 0 ? issue.labels.join(', ') : 'none';

    const commentsSection =
      notes.length === 0
        ? '_No comments._'
        : notes
            .map(
              (note, i) =>
                `### Comment ${i + 1} — @${note.author.username} (${note.created_at})\n\n${note.body}`
            )
            .join('\n\n---\n\n');

    const text = `# Issue #${issue.iid}: ${issue.title}

**Project:** ${projectPath}
**State:** ${issue.state}
**Type:** ${issue.issue_type ?? 'issue'}
**Author:** @${issue.author.username}
**Assignees:** ${assignees}
**Labels:** ${labels}
**Milestone:** ${milestone}
**Created:** ${issue.created_at}
**Updated:** ${issue.updated_at}${issue.closed_at ? `\n**Closed:** ${issue.closed_at}` : ''}${issue.due_date ? `\n**Due date:** ${issue.due_date}` : ''}
**Comments:** ${issue.user_notes_count}${issue.confidential ? '\n**Confidential:** yes' : ''}
**URL:** ${issue.web_url}

---

## Description

${issue.description ? issue.description.trim() : '_No description._'}

---

## Comments (${notes.length})

${commentsSection}`;

    return { content: [{ type: 'text', text }] };
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error fetching issue #${issueIid} from ${projectPath}: ${classifyGitlabError(error)}`,
        },
      ],
    };
  }
}
