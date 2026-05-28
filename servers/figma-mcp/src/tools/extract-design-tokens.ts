/**
 * Tool: extract_design_tokens
 * Extrait les design tokens (Figma Variables) depuis un fichier Figma
 */

import { FigmaClient } from '../client.js';

export const extractDesignTokensTool = {
  name: 'extract_design_tokens',
  description: 'Extract design tokens (Figma Variables) from a Figma file. Returns colors, typography, spacing, and effects tokens.',
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

interface ColorToken {
  name: string;
  value: string;
  type: 'color';
}

interface TextToken {
  name: string;
  fontSize: number;
  fontFamily: string;
  fontWeight: number;
}

interface SpacingToken {
  name: string;
  value: number;
}

interface EffectToken {
  name: string;
  type: string;
  radius?: number;
  offset?: { x: number; y: number };
}

interface DesignTokens {
  colors: ColorToken[];
  text: TextToken[];
  spacing: SpacingToken[];
  effects: EffectToken[];
}

/**
 * Convertit une couleur RGBA Figma en hex
 */
function rgbaToHex(r: number, g: number, b: number, a: number = 1): string {
  const toHex = (n: number) => {
    const hex = Math.round(n * 255).toString(16);
    return hex.length === 1 ? '0' + hex : hex;
  };
  
  const hex = `#${toHex(r)}${toHex(g)}${toHex(b)}`;
  return a < 1 ? `${hex}${toHex(a)}` : hex;
}

/**
 * Extrait les design tokens depuis les Figma Variables
 */
export async function extractDesignTokens(
  client: FigmaClient,
  fileId: string
): Promise<{ content: Array<{ type: string; text: string }> }> {
  try {
    const tokens = await client.getDesignTokens(fileId);

    if (!tokens.colors.length && !tokens.text.length && !tokens.spacing.length && !tokens.effects.length) {
      return {
        content: [
          {
            type: 'text',
            text: [
              `## Design Tokens`,
              '',
              '⚠️ **Aucun design token détecté**',
              '',
              'Ce fichier ne contient pas de Figma Variables configurées.',
              '',
              '**Recommandation :** Configurer les design tokens dans Figma Variables pour faciliter la synchronisation avec le code.',
            ].join('\n'),
          },
        ],
      };
    }

    // Formater la sortie
    const output: string[] = [
      `## Design Tokens extraits`,
      '',
    ];

    // Couleurs
    if (tokens.colors.length > 0) {
      output.push(`### Couleurs (${tokens.colors.length} tokens)`);
      output.push('');
      tokens.colors.forEach((token) => {
        output.push(`- \`${token.name}\` : ${token.value}`);
      });
      output.push('');
    }

    // Typographie
    if (tokens.text.length > 0) {
      output.push(`### Typographie (${tokens.text.length} tokens)`);
      output.push('');
      tokens.text.forEach((token) => {
        output.push(`- \`${token.name}\` : ${token.fontFamily} ${token.fontSize}px / ${token.fontWeight}`);
      });
      output.push('');
    }

    // Espacements
    if (tokens.spacing.length > 0) {
      output.push(`### Espacements (${tokens.spacing.length} tokens)`);
      output.push('');
      tokens.spacing.forEach((token) => {
        output.push(`- \`${token.name}\` : ${token.value}px`);
      });
      output.push('');
    }

    // Effets
    if (tokens.effects.length > 0) {
      output.push(`### Effets (${tokens.effects.length} tokens)`);
      output.push('');
      tokens.effects.forEach((token) => {
        const details = token.offset 
          ? `${token.type} (radius: ${token.radius}, offset: ${token.offset.x}/${token.offset.y})`
          : token.type;
        output.push(`- \`${token.name}\` : ${details}`);
      });
      output.push('');
    }

    output.push('---');
    output.push('');
    output.push('**Total :** ' + 
      `${tokens.colors.length} couleurs, ` +
      `${tokens.text.length} styles typo, ` +
      `${tokens.spacing.length} espacements, ` +
      `${tokens.effects.length} effets`
    );

    return {
      content: [
        {
          type: 'text',
          text: output.join('\n'),
        },
      ],
    };
  } catch (error) {
    // Si l'API ne supporte pas les Variables ou retourne une erreur
    return {
      content: [
        {
          type: 'text',
          text: [
            `## Design Tokens`,
            '',
            '⚠️ **Extraction impossible**',
            '',
            `Erreur : ${error instanceof Error ? error.message : 'Unknown error'}`,
            '',
            '**Cause possible :**',
            '- Les Figma Variables ne sont pas configurées sur ce fichier',
            '- Le fichier est dans un plan Figma qui ne supporte pas les Variables',
            '- Les permissions d\'accès sont insuffisantes',
          ].join('\n'),
        },
      ],
    };
  }
}
