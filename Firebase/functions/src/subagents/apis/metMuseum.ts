// metMuseum.ts
// Metropolitan Museum of Art Collection API client.
// Filters for public domain (CC0) images only.

import * as logger from "firebase-functions/logger";
import {APISearchResult, ImageAPIClient, USER_AGENT} from "./types";

const BASE_URL = "https://collectionapi.metmuseum.org/public/collection/v1";

// Response types from Met API
interface MetSearchResponse {
  total: number;
  objectIDs: number[] | null;
}

interface MetObjectResponse {
  objectID: number;
  isPublicDomain: boolean;
  primaryImage: string;
  primaryImageSmall: string;
  title: string;
  artistDisplayName?: string;
  artistDisplayBio?: string;
  objectDate?: string;
  medium?: string;
  department?: string;
  culture?: string;
  period?: string;
  objectURL: string;
}

/**
 * Search Metropolitan Museum of Art collection.
 * Only returns public domain (CC0) images.
 */
async function search(query: string, limit = 5): Promise<APISearchResult[]> {
  try {
    // Step 1: Search for object IDs
    const searchUrl = new URL(`${BASE_URL}/search`);
    searchUrl.searchParams.set("q", query);
    searchUrl.searchParams.set("hasImages", "true");

    const searchResponse = await fetch(searchUrl.toString(), {
      headers: {"User-Agent": USER_AGENT},
    });

    if (!searchResponse.ok) {
      logger.warn("Met Museum search error", {status: searchResponse.status});
      return [];
    }

    const searchData = (await searchResponse.json()) as MetSearchResponse;
    const objectIDs = searchData.objectIDs || [];

    if (objectIDs.length === 0) return [];

    // Step 2: Fetch object details (limit to avoid too many requests)
    // Fetch more than we need since some won't be public domain
    const idsToFetch = objectIDs.slice(0, limit * 3);
    const results: APISearchResult[] = [];

    // Fetch objects in parallel (Met allows 80 req/sec)
    const objectPromises = idsToFetch.map(async (id) => {
      try {
        const objectUrl = `${BASE_URL}/objects/${id}`;
        const response = await fetch(objectUrl, {
          headers: {"User-Agent": USER_AGENT},
        });
        if (!response.ok) return null;
        return (await response.json()) as MetObjectResponse;
      } catch {
        return null;
      }
    });

    const objects = await Promise.all(objectPromises);

    // Filter for public domain and build results
    for (const obj of objects) {
      if (results.length >= limit) break;
      if (!obj) continue;

      // Only include public domain items
      if (!obj.isPublicDomain) continue;

      // Must have an image
      const imageUrl = obj.primaryImage || obj.primaryImageSmall;
      if (!imageUrl) continue;

      // Build description from available fields
      const descParts: string[] = [];
      if (obj.artistDisplayName) descParts.push(obj.artistDisplayName);
      if (obj.objectDate) descParts.push(obj.objectDate);
      if (obj.medium) descParts.push(obj.medium);

      results.push({
        source: "met",
        image_url: imageUrl,
        thumbnail_url: obj.primaryImageSmall || imageUrl,
        title: obj.title,
        description: descParts.join(" | ") || undefined,
        attribution: {
          source: "Metropolitan Museum of Art",
          url: obj.objectURL,
          license: "CC0",
          author: obj.artistDisplayName,
        },
      });
    }

    logger.info("Met Museum search completed", {query, resultCount: results.length});
    return results;
  } catch (error) {
    logger.error("Met Museum search error", {error, query});
    return [];
  }
}

// Export as ImageAPIClient
export const metMuseumClient: ImageAPIClient = {
  name: "Metropolitan Museum of Art",
  search,
};
