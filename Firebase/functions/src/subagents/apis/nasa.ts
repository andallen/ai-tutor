// nasa.ts
// NASA Image and Video Library API client.
// All NASA content is public domain (US federal work).

import * as logger from "firebase-functions/logger";
import {APISearchResult, ImageAPIClient} from "./types";

const BASE_URL = "https://images-api.nasa.gov";

// Response types from NASA API
interface NASASearchResponse {
  collection: {
    items: NASAItem[];
  };
}

interface NASAItem {
  href: string; // Link to asset manifest
  data: Array<{
    nasa_id: string;
    title: string;
    description?: string;
    media_type: string;
    date_created?: string;
    center?: string;
    keywords?: string[];
  }>;
  links?: Array<{
    href: string;
    rel: string; // "preview" for thumbnail
    render?: string;
  }>;
}

/**
 * Search NASA Image and Video Library.
 * No authentication required.
 */
async function search(query: string, limit = 5): Promise<APISearchResult[]> {
  try {
    const url = new URL(`${BASE_URL}/search`);
    url.searchParams.set("q", query);
    url.searchParams.set("media_type", "image");

    const response = await fetch(url.toString());

    if (!response.ok) {
      logger.warn("NASA API error", {status: response.status});
      return [];
    }

    const data = (await response.json()) as NASASearchResponse;
    const items = data.collection?.items || [];

    // Map to common result format
    const results: APISearchResult[] = [];

    for (const item of items.slice(0, limit)) {
      const metadata = item.data?.[0];
      if (!metadata) continue;

      // Get thumbnail URL from links
      const thumbnailLink = item.links?.find((l) => l.rel === "preview");
      const imageUrl = thumbnailLink?.href;

      if (!imageUrl) continue;

      results.push({
        source: "nasa",
        image_url: imageUrl,
        thumbnail_url: imageUrl,
        title: metadata.title,
        description: metadata.description?.substring(0, 500),
        attribution: {
          source: "NASA",
          url: `https://images.nasa.gov/details/${metadata.nasa_id}`,
          license: "Public Domain",
        },
      });
    }

    logger.info("NASA search completed", {query, resultCount: results.length});
    return results;
  } catch (error) {
    logger.error("NASA search error", {error, query});
    return [];
  }
}

// Export as ImageAPIClient
export const nasaClient: ImageAPIClient = {
  name: "NASA",
  search,
};
