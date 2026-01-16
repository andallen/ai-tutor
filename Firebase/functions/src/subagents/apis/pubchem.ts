// pubchem.ts
// PubChem PUG-REST API client for molecular structure images.
// All PubChem content is public domain (NIH/NLM federal resource).

import * as logger from "firebase-functions/logger";
import {APISearchResult, ImageAPIClient} from "./types";

const BASE_URL = "https://pubchem.ncbi.nlm.nih.gov/rest/pug";

// Response type for compound search
interface PubChemSearchResponse {
  IdentifierList?: {
    CID: number[];
  };
}

// Response type for compound properties
interface PubChemPropertyResponse {
  PropertyTable?: {
    Properties: Array<{
      CID: number;
      MolecularFormula?: string;
      MolecularWeight?: number;
      IUPACName?: string;
    }>;
  };
}

/**
 * Extracts compound name from a search query.
 * Handles queries like "caffeine molecule", "structure of aspirin", etc.
 */
function extractCompoundName(query: string): string {
  const lowerQuery = query.toLowerCase();

  // Common patterns: "X molecule", "structure of X", "molecular structure of X"
  const patterns = [
    /structure\s+of\s+([a-zA-Z0-9-]+)/i,
    /molecular\s+structure\s+of\s+([a-zA-Z0-9-]+)/i,
    /([a-zA-Z0-9-]+)\s+molecule/i,
    /([a-zA-Z0-9-]+)\s+structure/i,
    /([a-zA-Z0-9-]+)\s+compound/i,
    /([a-zA-Z0-9-]+)\s+chemical/i,
  ];

  for (const pattern of patterns) {
    const match = query.match(pattern);
    if (match && match[1]) {
      return match[1].toLowerCase();
    }
  }

  // Fallback: extract first word that isn't a stop word
  const stopWords = new Set([
    "the", "a", "an", "of", "structure", "molecule", "molecular",
    "chemical", "compound", "diagram", "show", "display",
  ]);

  const words = lowerQuery.split(/\s+/);
  for (const word of words) {
    if (!stopWords.has(word) && word.length > 2) {
      return word;
    }
  }

  return "";
}

/**
 * Search PubChem for molecular structure images.
 * Returns 2D structure diagram URLs.
 */
async function search(query: string, limit = 3): Promise<APISearchResult[]> {
  try {
    const compoundName = extractCompoundName(query);
    if (!compoundName) return [];

    // Step 1: Search for compound by name to get CID
    const searchUrl = `${BASE_URL}/compound/name/${encodeURIComponent(compoundName)}/cids/JSON`;
    const searchResponse = await fetch(searchUrl);

    if (!searchResponse.ok) {
      // Compound not found
      logger.info("PubChem compound not found", {query: compoundName});
      return [];
    }

    const searchData = (await searchResponse.json()) as PubChemSearchResponse;
    const cids = searchData.IdentifierList?.CID || [];

    if (cids.length === 0) return [];

    // Step 2: Get properties for the compound(s)
    const cidList = cids.slice(0, limit).join(",");
    const propsUrl = `${BASE_URL}/compound/cid/${cidList}/property/MolecularFormula,MolecularWeight,IUPACName/JSON`;
    const propsResponse = await fetch(propsUrl);

    let properties: PubChemPropertyResponse["PropertyTable"] = undefined;
    if (propsResponse.ok) {
      const propsData = (await propsResponse.json()) as PubChemPropertyResponse;
      properties = propsData.PropertyTable;
    }

    // Step 3: Build results with direct image URLs
    const results: APISearchResult[] = [];

    for (let i = 0; i < Math.min(cids.length, limit); i++) {
      const cid = cids[i];
      const props = properties?.Properties?.find((p) => p.CID === cid);

      // Direct URL to 2D structure PNG (300x300)
      const imageUrl = `${BASE_URL}/compound/cid/${cid}/PNG?image_size=300x300`;

      const title = props?.IUPACName ||
        `${compoundName.charAt(0).toUpperCase() + compoundName.slice(1)} (CID: ${cid})`;

      const formula = props?.MolecularFormula;
      const weight = props?.MolecularWeight;
      const weightStr = typeof weight === "number" ? weight.toFixed(2) : "";
      const description = formula ?
        `Molecular formula: ${formula}${weightStr ? `, MW: ${weightStr}` : ""}` :
        undefined;

      results.push({
        source: "pubchem",
        image_url: imageUrl,
        title: title,
        description: description,
        attribution: {
          source: "PubChem",
          url: `https://pubchem.ncbi.nlm.nih.gov/compound/${cid}`,
          license: "Public Domain",
        },
      });
    }

    logger.info("PubChem search completed", {query: compoundName, resultCount: results.length});
    return results;
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    logger.error("PubChem search error", {errorMessage, query});
    return [];
  }
}

// Export as ImageAPIClient
export const pubchemClient: ImageAPIClient = {
  name: "PubChem",
  search,
};
