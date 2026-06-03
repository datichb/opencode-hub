/**
 * Tool: get_node_details
 * Récupère les détails complets d'un nœud Figma spécifique par son ID.
 * Utile pour analyser un écran, un composant ou une zone précise d'une maquette
 * (ex: panneau de filtres, tableau de données, formulaire).
 */

import { FigmaClient, FigmaNode } from '../client.js';

export const getNodeDetailsTool = {
  name: 'get_node_details',
  description:
    'Get the complete details of a specific Figma node by its ID. ' +
    'Returns layout mode (horizontal/vertical), spacing, padding, fills, ' +
    'component properties, geometry and children structure. ' +
    'Use this when you have a node ID from a Figma URL (?node-id=...) and need ' +
    'to understand the exact implementation details of a screen area.',
  inputSchema: {
    type: 'object',
    properties: {
      fileId: {
        type: 'string',
        description: 'Figma file ID (file key from the URL)',
      },
      nodeId: {
        type: 'string',
        description: 'Node ID to inspect (from Figma URL: ?node-id=122-29189 → "122-29189")',
      },
    },
    required: ['fileId', 'nodeId'],
  },
};

/** Formate une couleur RGBA Figma en hex lisible */
function formatColor(color?: { r: number; g: number; b: number; a: number }): string {
  if (!color) return 'N/A';
  const toHex = (n: number) => Math.round(n * 255).toString(16).padStart(2, '0');
  const hex = `#${toHex(color.r)}${toHex(color.g)}${toHex(color.b)}`;
  return color.a < 1 ? `${hex} (opacity: ${Math.round(color.a * 100)}%)` : hex;
}

/** Formate la section layout d'un nœud */
function formatLayout(node: FigmaNode): string[] {
  const lines: string[] = [];

  if (node.layoutMode && node.layoutMode !== 'NONE') {
    lines.push(`**Layout :** ${node.layoutMode}`);
    if (node.primaryAxisAlignItems) lines.push(`**Axe principal :** ${node.primaryAxisAlignItems}`);
    if (node.counterAxisAlignItems) lines.push(`**Axe secondaire :** ${node.counterAxisAlignItems}`);
    if (node.itemSpacing !== undefined) lines.push(`**Espacement entre éléments :** ${node.itemSpacing}px`);
    const padding = [
      node.paddingTop !== undefined ? `haut: ${node.paddingTop}px` : null,
      node.paddingRight !== undefined ? `droite: ${node.paddingRight}px` : null,
      node.paddingBottom !== undefined ? `bas: ${node.paddingBottom}px` : null,
      node.paddingLeft !== undefined ? `gauche: ${node.paddingLeft}px` : null,
    ].filter(Boolean);
    if (padding.length > 0) lines.push(`**Padding :** ${padding.join(', ')}`);
  } else {
    lines.push('**Layout :** Aucun (positionnement absolu)');
  }

  if (node.absoluteBoundingBox) {
    const bb = node.absoluteBoundingBox;
    lines.push(`**Dimensions :** ${Math.round(bb.width)}×${Math.round(bb.height)}px`);
    lines.push(`**Position :** x=${Math.round(bb.x)}, y=${Math.round(bb.y)}`);
  }

  return lines;
}

/** Formate les propriétés de composant */
function formatComponentProps(node: FigmaNode): string[] {
  const lines: string[] = [];

  if (node.componentPropertyDefinitions && Object.keys(node.componentPropertyDefinitions).length > 0) {
    lines.push('**Propriétés du composant :**');
    for (const [propName, propDef] of Object.entries(node.componentPropertyDefinitions)) {
      const opts = propDef.variantOptions ? ` [${propDef.variantOptions.join(' | ')}]` : '';
      lines.push(`  - ${propName} (${propDef.type})${opts} — défaut: ${JSON.stringify(propDef.defaultValue)}`);
    }
  }

  if (node.componentProperties && Object.keys(node.componentProperties).length > 0) {
    lines.push('**Valeurs des propriétés :**');
    for (const [propName, propVal] of Object.entries(node.componentProperties)) {
      lines.push(`  - ${propName}: ${JSON.stringify(propVal.value)}`);
    }
  }

  return lines;
}

/** Formate les fills (couleurs de fond) */
function formatFills(node: FigmaNode): string[] {
  if (!node.fills || node.fills.length === 0) return [];
  const lines = ['**Fills :**'];
  for (const fill of node.fills) {
    if (fill.type === 'SOLID') {
      lines.push(`  - Solide : ${formatColor(fill.color)}`);
    } else {
      lines.push(`  - ${fill.type}`);
    }
  }
  return lines;
}

/** Résumé des enfants directs */
function formatChildren(node: FigmaNode): string[] {
  if (!node.children || node.children.length === 0) return ['**Enfants :** Aucun (nœud feuille)'];

  const lines = [`**Enfants directs (${node.children.length}) :**`];
  for (const child of node.children.slice(0, 20)) {
    const childInfo = child.layoutMode && child.layoutMode !== 'NONE'
      ? ` [${child.layoutMode}]`
      : '';
    const childSize = child.absoluteBoundingBox
      ? ` — ${Math.round(child.absoluteBoundingBox.width)}×${Math.round(child.absoluteBoundingBox.height)}px`
      : '';
    lines.push(`  - **${child.name}** (${child.type})${childInfo}${childSize}`);
  }
  if (node.children.length > 20) {
    lines.push(`  ... et ${node.children.length - 20} autres enfants`);
  }
  return lines;
}

export async function getNodeDetails(
  client: FigmaClient,
  fileId: string,
  nodeId: string
): Promise<{ content: Array<{ type: string; text: string }> }> {
  try {
    const node = await client.getNode(fileId, nodeId);
    const url = client.generateFileUrl(fileId, nodeId);

    const sections: string[] = [
      `## Détails du nœud Figma`,
      '',
      `**Nom :** ${node.name}`,
      `**Type :** ${node.type}`,
      `**ID :** ${nodeId}`,
      `**URL :** ${url}`,
      '',
      '### Layout & Géométrie',
      '',
      ...formatLayout(node),
      '',
      '### Visuel',
      '',
      ...formatFills(node),
      node.opacity !== undefined && node.opacity < 1
        ? `**Opacité :** ${Math.round(node.opacity * 100)}%`
        : '',
      '',
      ...formatComponentProps(node),
    ];

    if (node.characters) {
      sections.push('', `### Contenu textuel`, '', `\`\`\``, node.characters, `\`\`\``);
    }

    sections.push('', '### Structure enfants', '', ...formatChildren(node));

    const text = sections
      .filter(line => line !== null && line !== undefined)
      .join('\n')
      .replace(/\n{3,}/g, '\n\n')
      .trim();

    return { content: [{ type: 'text', text }] };
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    const isUnavailable = msg.includes('indisponible') || msg.includes('timeout');
    const isAuth = msg.includes('401') || msg.includes('403') || msg.includes('Token Figma');
    const isNotFound = msg.includes('introuvable') || msg.includes('404');

    const prefix = isUnavailable
      ? '⚠️ Figma indisponible'
      : isAuth
      ? '⚠️ Erreur d\'authentification Figma'
      : isNotFound
      ? 'ℹ️ Nœud introuvable'
      : '❌ Erreur Figma';

    return {
      content: [{
        type: 'text',
        text: `${prefix} lors de la récupération du nœud ${nodeId} : ${msg}`,
      }],
    };
  }
}
