// smithsonian.ts
// Smithsonian Open Access API client.
// All Open Access content is CC0.
// Requires free API key from api.data.gov.

import * as logger from "firebase-functions/logger";
import {APISearchResult, ImageAPIClient} from "./types";

const BASE_URL = "https://api.si.edu/openaccess/api/v1.0";

// Response types from Smithsonian API
interface SmithsonianResponse {
  response: {
    rowCount: number;
    rows: SmithsonianRow[];
  };
}

interface SmithsonianRow {
  id: string;
  title: string;
  content: {
    descriptiveNonRepeating?: {
      title?: {content: string};
      unit_code?: string;
      record_link?: string;
      online_media?: {
        media?: Array<{
          content: string; // Image URL
          thumbnail?: string;
          type?: string;
        }>;
      };
    };
    freetext?: {
      name?: Array<{content: string}>; // Creator/artist
      notes?: Array<{content: string}>; // Description
      physicalDescription?: Array<{content: string}>;
    };
  };
}

/**
 * Get Smithsonian API key from environment.
 * Register for free at: https://api.data.gov/signup/
 *
 * For local: export SMITHSONIAN_API_KEY="your_key"
 * For deployed: Set in Firebase Console under Functions > Environment Variables
 */
function getApiKey(): string | null {
  const key = process.env.SMITHSONIAN_API_KEY;
  if (!key) {
    logger.warn("Smithsonian API key not configured. Set SMITHSONIAN_API_KEY environment variable.");
  }
  return key || null;
}

/**
 * Extract first image URL from media array.
 */
function extractImageUrl(media: SmithsonianRow["content"]["descriptiveNonRepeating"]): {
  imageUrl: string | null;
  thumbnailUrl: string | null;
} {
  const mediaItems = media?.online_media?.media;
  if (!mediaItems || mediaItems.length === 0) {
    return {imageUrl: null, thumbnailUrl: null};
  }

  // Find first image media item
  for (const item of mediaItems) {
    if (item.type?.includes("image") || item.content?.includes("ids.si.edu")) {
      return {
        imageUrl: item.content,
        thumbnailUrl: item.thumbnail || item.content,
      };
    }
  }

  // Fallback to first item
  const first = mediaItems[0];
  return {
    imageUrl: first.content,
    thumbnailUrl: first.thumbnail || first.content,
  };
}

/**
 * Search Smithsonian Open Access collection.
 * All results are CC0 (Open Access program).
 */
async function search(query: string, limit = 5): Promise<APISearchResult[]> {
  const apiKey = getApiKey();
  if (!apiKey) {
    return [];
  }

  try {
    // Build search URL targeting collections with images
    // CHNDM = Cooper Hewitt Design Museum (lots of images)
    // NMAAHC = National Museum of African American History and Culture
    // SAAM = Smithsonian American Art Museum
    // NPG = National Portrait Gallery
    // NPM = National Postal Museum
    const url = new URL(`${BASE_URL}/search`);
    url.searchParams.set("q", `${query} AND (unit_code:CHNDM OR unit_code:NMAAHC OR unit_code:SAAM OR unit_code:NPG OR unit_code:NPM OR unit_code:NMAH)`);
    url.searchParams.set("rows", String(limit * 5)); // Fetch extra since many won't have images
    url.searchParams.set("api_key", apiKey);

    const response = await fetch(url.toString());

    if (!response.ok) {
      logger.warn("Smithsonian API error", {status: response.status});
      return [];
    }

    const data = (await response.json()) as SmithsonianResponse;
    const rows = data.response?.rows || [];

    // Build results
    const results: APISearchResult[] = [];

    for (const row of rows) {
      if (results.length >= limit) break;

      const descriptive = row.content?.descriptiveNonRepeating;
      const {imageUrl, thumbnailUrl} = extractImageUrl(descriptive);

      if (!imageUrl) continue;

      // Get title
      const title = descriptive?.title?.content || row.title || "Untitled";

      // Get creator/author
      const names = row.content?.freetext?.name;
      const author = names?.[0]?.content;

      // Get description
      const notes = row.content?.freetext?.notes;
      const description = notes?.[0]?.content;

      // Build record URL
      const recordLink = descriptive?.record_link ||
        `https://collections.si.edu/search/detail/${encodeURIComponent(row.id)}`;

      results.push({
        source: "smithsonian",
        image_url: imageUrl,
        thumbnail_url: thumbnailUrl || imageUrl,
        title: title,
        description: description?.substring(0, 500),
        attribution: {
          source: "Smithsonian Institution",
          url: recordLink,
          license: "CC0",
          author: author,
        },
      });
    }

    logger.info("Smithsonian search completed", {query, resultCount: results.length});
    return results;
  } catch (error) {
    logger.error("Smithsonian search error", {error, query});
    return [];
  }
}

// Export as ImageAPIClient
export const smithsonianClient: ImageAPIClient = {
  name: "Smithsonian Institution",
  search,
};
