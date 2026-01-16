// libraryOfCongress.ts
// Library of Congress Prints & Photographs API client.
// Filters for unrestricted (public domain) images only.

import * as logger from "firebase-functions/logger";
import {APISearchResult, ImageAPIClient, USER_AGENT} from "./types";

const BASE_URL = "https://www.loc.gov/pictures";

// Response types from LOC API
interface LOCSearchResponse {
  results: LOCSearchResult[];
}

interface LOCSearchResult {
  pk: string;
  title: string;
  creator?: string;
  image?: {
    full?: string;
    thumb?: string;
    square?: string;
  };
  links?: {
    item?: string;
  };
}

interface LOCItemResponse {
  pk: string;
  title: string;
  creator?: string;
  unrestricted: boolean;
  rights_information?: string;
  image?: {
    full?: string;
    thumb?: string;
    square?: string;
  };
}

/**
 * Search Library of Congress Prints & Photographs.
 * Only returns unrestricted (public domain) images.
 */
async function search(query: string, limit = 5): Promise<APISearchResult[]> {
  try {
    // Step 1: Search for items
    const searchUrl = new URL(`${BASE_URL}/search/`);
    searchUrl.searchParams.set("q", query);
    searchUrl.searchParams.set("fo", "json");
    searchUrl.searchParams.set("c", String(limit * 2)); // Fetch extra since we filter

    const searchResponse = await fetch(searchUrl.toString(), {
      headers: {"User-Agent": USER_AGENT},
    });

    if (!searchResponse.ok) {
      logger.warn("LOC search error", {status: searchResponse.status});
      return [];
    }

    const searchData = (await searchResponse.json()) as LOCSearchResponse;
    const items = searchData.results || [];

    if (items.length === 0) return [];

    // Step 2: Fetch individual items to check unrestricted flag
    const results: APISearchResult[] = [];

    for (const item of items) {
      if (results.length >= limit) break;

      // Skip items without images
      if (!item.image?.thumb && !item.image?.full) continue;

      // Fetch item details to check unrestricted flag
      const itemUrl = `${BASE_URL}/item/${item.pk}/?fo=json`;
      const itemResponse = await fetch(itemUrl, {
        headers: {"User-Agent": USER_AGENT},
      });

      if (!itemResponse.ok) continue;

      const itemData = (await itemResponse.json()) as LOCItemResponse;

      // Only include unrestricted items (public domain)
      if (!itemData.unrestricted) {
        logger.debug("LOC item restricted, skipping", {pk: item.pk});
        continue;
      }

      const imageUrl = itemData.image?.full || itemData.image?.thumb || item.image?.full || item.image?.thumb;
      if (!imageUrl) continue;

      results.push({
        source: "loc",
        image_url: imageUrl,
        thumbnail_url: itemData.image?.thumb || item.image?.thumb,
        title: itemData.title || item.title,
        description: itemData.rights_information,
        attribution: {
          source: "Library of Congress",
          url: `https://www.loc.gov/pictures/item/${item.pk}/`,
          license: "Public Domain",
          author: itemData.creator || item.creator,
        },
      });
    }

    logger.info("LOC search completed", {query, resultCount: results.length});
    return results;
  } catch (error) {
    logger.error("LOC search error", {error, query});
    return [];
  }
}

// Export as ImageAPIClient
export const locClient: ImageAPIClient = {
  name: "Library of Congress",
  search,
};
