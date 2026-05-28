/**
 * Client pour l'API Figma
 */

import axios, { AxiosInstance } from 'axios';
import { FigmaConfig } from './config.js';

export interface FigmaFile {
  key: string;
  name: string;
  thumbnail_url?: string;
  last_modified: string;
}

export interface FigmaProject {
  id: string;
  name: string;
}

export interface FigmaNode {
  id: string;
  name: string;
  type: string;
  children?: FigmaNode[];
}

export interface FigmaFileResponse {
  name: string;
  lastModified: string;
  thumbnailUrl?: string;
  document: FigmaNode;
}

export class FigmaClient {
  private client: AxiosInstance;
  private teamId: string;

  constructor(config: FigmaConfig) {
    this.client = axios.create({
      baseURL: config.baseUrl,
      headers: {
        'X-Figma-Token': config.token,
      },
      timeout: 10000,
    });
    this.teamId = config.teamId;
  }

  /**
   * Recherche des fichiers Figma par nom
   */
  async searchFiles(query: string): Promise<FigmaFile[]> {
    try {
      // Récupérer tous les projets de la team
      const { data: projectsData } = await this.client.get(
        `/teams/${this.teamId}/projects`
      );

      const allFiles: FigmaFile[] = [];

      // Pour chaque projet, récupérer les fichiers
      for (const project of projectsData.projects) {
        try {
          const { data: filesData } = await this.client.get(
            `/projects/${project.id}/files`
          );

          // Filtrer par nom
          const matchingFiles = filesData.files.filter((file: FigmaFile) =>
            file.name.toLowerCase().includes(query.toLowerCase())
          );

          allFiles.push(...matchingFiles);
        } catch (error) {
          // Ignorer les erreurs de projet individuel
          console.error(`Error fetching files for project ${project.id}:`, error);
        }
      }

      return allFiles;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        throw new Error(
          `Figma API error: ${error.response?.status} - ${error.response?.data?.err || error.message}`
        );
      }
      throw error;
    }
  }

  /**
   * Récupère la structure d'un fichier Figma
   */
  async getFile(fileId: string): Promise<FigmaFileResponse> {
    try {
      const { data } = await this.client.get(`/files/${fileId}`);

      return {
        name: data.name,
        lastModified: data.lastModified,
        thumbnailUrl: data.thumbnailUrl,
        document: data.document,
      };
    } catch (error) {
      if (axios.isAxiosError(error)) {
        throw new Error(
          `Figma API error: ${error.response?.status} - ${error.response?.data?.err || error.message}`
        );
      }
      throw error;
    }
  }

  /**
   * Extrait les frames d'un fichier
   */
  extractFrames(node: FigmaNode): FigmaNode[] {
    const frames: FigmaNode[] = [];

    const traverse = (n: FigmaNode) => {
      if (n.type === 'FRAME' || n.type === 'COMPONENT' || n.type === 'COMPONENT_SET') {
        frames.push(n);
      }
      if (n.children) {
        n.children.forEach(traverse);
      }
    };

    traverse(node);
    return frames;
  }

  /**
   * Compte les composants d'un fichier
   */
  countComponents(node: FigmaNode): number {
    let count = 0;

    const traverse = (n: FigmaNode) => {
      if (n.type === 'COMPONENT' || n.type === 'COMPONENT_SET') {
        count++;
      }
      if (n.children) {
        n.children.forEach(traverse);
      }
    };

    traverse(node);
    return count;
  }

  /**
   * Génère l'URL Figma vers un fichier
   */
  generateFileUrl(fileId: string, nodeId?: string): string {
    const baseUrl = `https://www.figma.com/file/${fileId}`;
    return nodeId ? `${baseUrl}?node-id=${nodeId}` : baseUrl;
  }

  /**
   * Extrait les design tokens (Figma Variables) depuis un fichier
   */
  async getDesignTokens(fileId: string): Promise<{
    colors: Array<{ name: string; value: string; type: 'color' }>;
    text: Array<{ name: string; fontSize: number; fontFamily: string; fontWeight: number }>;
    spacing: Array<{ name: string; value: number }>;
    effects: Array<{ name: string; type: string; radius?: number; offset?: { x: number; y: number } }>;
  }> {
    try {
      // Récupérer les variables Figma (API endpoint pour les variables)
      const { data } = await this.client.get(`/files/${fileId}/variables/local`);

      const colors: Array<{ name: string; value: string; type: 'color' }> = [];
      const text: Array<{ name: string; fontSize: number; fontFamily: string; fontWeight: number }> = [];
      const spacing: Array<{ name: string; value: number }> = [];
      const effects: Array<{ name: string; type: string; radius?: number; offset?: { x: number; y: number } }> = [];

      // Parser les variables selon leur type
      if (data.meta && data.meta.variableCollections) {
        for (const collectionId of Object.keys(data.meta.variableCollections)) {
          const collection = data.meta.variableCollections[collectionId];
          
          for (const varId of collection.variableIds || []) {
            const variable = data.meta.variables?.[varId];
            if (!variable) continue;

            const varName = variable.name;
            const varType = variable.resolvedType;

            // Extraire la valeur depuis le premier mode
            const firstModeId = collection.modes?.[0]?.modeId;
            if (!firstModeId) continue;

            const varValue = variable.valuesByMode?.[firstModeId];
            if (varValue === undefined) continue;

            // Catégoriser selon le type
            if (varType === 'COLOR') {
              const { r, g, b, a } = varValue;
              const hex = this.rgbaToHex(r, g, b, a);
              colors.push({ name: varName, value: hex, type: 'color' });
            } else if (varType === 'FLOAT') {
              // Heuristique : si le nom contient "space", "spacing", "gap", c'est un spacing
              if (/space|spacing|gap|margin|padding/i.test(varName)) {
                spacing.push({ name: varName, value: varValue });
              }
            }
          }
        }
      }

      // Récupérer les styles de texte (text styles)
      const { data: stylesData } = await this.client.get(`/files/${fileId}/styles`);
      
      if (stylesData.meta && stylesData.meta.styles) {
        for (const style of Object.values(stylesData.meta.styles) as any[]) {
          if (style.style_type === 'TEXT') {
            const textStyle = style;
            text.push({
              name: textStyle.name,
              fontSize: textStyle.fontSize || 16,
              fontFamily: textStyle.fontFamily || 'Sans-serif',
              fontWeight: textStyle.fontWeight || 400,
            });
          }
        }
      }

      // Récupérer les styles d'effet (effect styles)
      if (stylesData.meta && stylesData.meta.styles) {
        for (const style of Object.values(stylesData.meta.styles) as any[]) {
          if (style.style_type === 'EFFECT') {
            const effectStyle = style;
            effects.push({
              name: effectStyle.name,
              type: effectStyle.type || 'UNKNOWN',
              radius: effectStyle.radius,
              offset: effectStyle.offset,
            });
          }
        }
      }

      return { colors, text, spacing, effects };
    } catch (error) {
      if (axios.isAxiosError(error)) {
        // Si l'endpoint n'existe pas ou retourne 404, retourner des tokens vides
        if (error.response?.status === 404 || error.response?.status === 403) {
          return { colors: [], text: [], spacing: [], effects: [] };
        }
        throw new Error(
          `Figma API error: ${error.response?.status} - ${error.response?.data?.err || error.message}`
        );
      }
      throw error;
    }
  }

  /**
   * Convertit une couleur RGBA Figma en hex
   */
  private rgbaToHex(r: number, g: number, b: number, a: number = 1): string {
    const toHex = (n: number) => {
      const hex = Math.round(n * 255).toString(16);
      return hex.length === 1 ? '0' + hex : hex;
    };
    
    const hex = `#${toHex(r)}${toHex(g)}${toHex(b)}`;
    return a < 1 ? `${hex}${toHex(a)}` : hex;
  }
}
