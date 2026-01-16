// artInstituteChicago.ts
// Art Institute of Chicago API client.
// Filters for public domain (CC0) images only.
// Uses IIIF for image URLs.

import * as logger from "firebase-functions/logger";
import {APISearchResult, ImageAPIClient, USER_AGENT} from "./types";

const BASE_URL = "https://api.artic.edu/api/v1";
const IIIF_BASE = "https://www.artic.edu/iiif/2";

// Response types from Art Institute API
interface ArtInstituteSearchResponse {
  data: ArtInstituteArtwork[];
  config: {
    iiif_url: string;
  };
}

interface ArtInstituteArtwork {
  id: number;
  title: string;
  image_id: string | null;
  is_public_domain: boolean;
  artist_title?: string;
  artist_display?: string;
  date_display?: string;
  medium_display?: string;
  department_title?: string;
  artwork_type_title?: string;
}

/**
 * Construct IIIF image URL from image_id.
 * Uses cached size (843 width) for faster response.
 */
function buildImageUrl(imageId: string, iiifBase: string = IIIF_BASE): string {
  // Format: {base}/{id}/{region}/{size}/{rotation}/{quality}.{format}
  // 843 width is cached by Art Institute for faster response
  return `${iiifBase}/${imageId}/full/843,/0/default.jpg`;
}

/**
 * Build thumbnail URL (smaller size).
 */
function buildThumbnailUrl(imageId: string, iiifBase: string = IIIF_BASE): string {
  return `${iiifBase}/${imageId}/full/200,/0/default.jpg`;
}

/**
 * Search Art Institute of Chicago collection.
 * Only returns public domain (CC0) images.
 */
async function search(query: string, limit = 5): Promise<APISearchResult[]> {
  try {
    // Build search URL with public domain filter
    const searchUrl = new URL(`${BASE_URL}/artworks/search`);
    searchUrl.searchParams.set("q", query);
    searchUrl.searchParams.set("fields", "id,title,image_id,is_public_domain,artist_title,artist_display,date_display,medium_display");
    searchUrl.searchParams.set("limit", String(limit * 2)); // Fetch extra in case some don't have images
    // Filter for public domain only
    searchUrl.searchParams.set("query[term][is_public_domain]", "true");

    const response = await fetch(searchUrl.toString(), {
      headers: {"User-Agent": USER_AGENT},
    });

    if (!response.ok) {
      logger.warn("Art Institute search error", {status: response.status});
      return [];
    }

    const data = (await response.json()) as ArtInstituteSearchResponse;
    const artworks = data.data || [];
    const iiifBase = data.config?.iiif_url || IIIF_BASE;

    // Build results
    const results: APISearchResult[] = [];

    for (const artwork of artworks) {
      if (results.length >= limit) break;

      // Skip items without images or not public domain
      if (!artwork.image_id || !artwork.is_public_domain) continue;

      // Build description from available fields
      const descParts: string[] = [];
      if (artwork.artist_title) descParts.push(artwork.artist_title);
      if (artwork.date_display) descParts.push(artwork.date_display);
      if (artwork.medium_display) descParts.push(artwork.medium_display);

      results.push({
        source: "artic",
        image_url: buildImageUrl(artwork.image_id, iiifBase),
        thumbnail_url: buildThumbnailUrl(artwork.image_id, iiifBase),
        title: artwork.title,
        description: descParts.join(" | ") || undefined,
        attribution: {
          source: "Art Institute of Chicago",
          url: `https://www.artic.edu/artworks/${artwork.id}`,
          license: "CC0",
          author: artwork.artist_title,
        },
      });
    }

    logger.info("Art Institute search completed", {query, resultCount: results.length});
    return results;
  } catch (error) {
    logger.error("Art Institute search error", {error, query});
    return [];
  }
}

// Export as ImageAPIClient
export const artInstituteClient: ImageAPIClient = {
  name: "Art Institute of Chicago",
  search,
};
