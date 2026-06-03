/**
 * Tool: get_file_structure
 * Récupère la structure d'un fichier Figma (frames, composants)
 */

import { FigmaClient } from '../client.js';

export const getFileStructureTool = {
  name: 'get_file_structure',
  description: 'Get the structure of a Figma file (frames, components). Returns frames list and component count.',
  inputSchema: {
    type: 'object',
    properties: {
      fileId: {
        type: 'string',
        description: 'Figma file ID (file key)',
      },
    },
    required: ['fileId'],
  },
};

export async function getFileStructure(
  client: FigmaClient,
  fileId: string
): Promise<{ content: Array<{ type: string; text: string }> }> {
  try {
    const file = await client.getFile(fileId);
    const frames = client.extractFrames(file.document);
    const componentsCount = client.countComponents(file.document);

    // Formater les frames
    const framesList = frames.slice(0, 20).map((frame) => {
      const url = client.generateFileUrl(fileId, frame.id);
      return `- **${frame.name}** (${frame.type})\n  URL: ${url}`;
    });

    const hasMore = frames.length > 20;

    const output = [
      `## Structure du fichier : ${file.name}`,
      '',
      `**Dernière modification :** ${new Date(file.lastModified).toLocaleDateString('fr-FR')}`,
      `**Frames détectées :** ${frames.length}`,
      `**Composants détectés :** ${componentsCount}`,
      '',
      `### Frames principales${hasMore ? ' (20 premières)' : ''}`,
      '',
      framesList.join('\n\n'),
    ];

    if (hasMore) {
      output.push('', `... et ${frames.length - 20} autres frames`);
    }

    return {
      content: [
        {
          type: 'text',
          text: output.join('\n'),
        },
      ],
    };
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    const isUnavailable = msg.includes('indisponible') || msg.includes('timeout');
    const isAuth = msg.includes('401') || msg.includes('403') || msg.includes('Token Figma');
    const prefix = isUnavailable
      ? '⚠️ Figma indisponible'
      : isAuth
      ? '⚠️ Erreur d\'authentification Figma'
      : '❌ Erreur Figma';
    return {
      content: [
        {
          type: 'text',
          text: `${prefix} lors de la récupération de la structure (${fileId}) : ${msg}`,
        },
      ],
    };
  }
}
