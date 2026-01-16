// wikimedia.ts
// Wikimedia Commons API client.
// Filters for commercially-safe licenses only (CC0, CC BY, CC BY-SA, Public Domain).
// Rejects NC (NonCommercial) licenses.

import * as logger from "firebase-functions/logger";
import {APISearchResult, ImageAPIClient, USER_AGENT} from "./types";

const BASE_URL = "https://commons.wikimedia.org/w/api.php";

// Response types from Wikimedia API
interface WikimediaResponse {
  query?: {
    pages?: Record<string, WikimediaPage>;
  };
}

interface WikimediaPage {
  pageid: number;
  title: string;
  imageinfo?: WikimediaImageInfo[];
}

interface WikimediaImageInfo {
  url: string;
  thumburl?: string;
  descriptionurl: string;
  extmetadata?: {
    Copyrighted?: {value: string};
    LicenseShortName?: {value: string};
    License?: {value: string};
    Artist?: {value: string};
    ImageDescription?: {value: string};
    AttributionRequired?: {value: string};
  };
}

/**
 * Check if a Wikimedia image has a commercially-safe license.
 * Returns true for: Public Domain, CC0, CC BY, CC BY-SA
 * Returns false for: CC BY-NC, CC BY-NC-SA, or unknown licenses
 */
function isCommerciallySafe(extmetadata: WikimediaImageInfo["extmetadata"]): boolean {
  if (!extmetadata) return false;

  // Public domain = always safe
  if (extmetadata.Copyrighted?.value === "False") {
    return true;
  }

  const license = extmetadata.LicenseShortName?.value || "";

  // Reject NonCommercial licenses
  if (license.includes("NC") || license.toLowerCase().includes("noncommercial")) {
    return false;
  }

  // Accept known safe licenses
  if (
    license === "Public domain" ||
    license === "CC0" ||
    license.startsWith("CC BY ") || // CC BY 2.0, CC BY 3.0, CC BY 4.0
    license.startsWith("CC BY-SA ") || // CC BY-SA is OK for commercial use
    license === "CC-BY" ||
    license === "CC-BY-SA"
  ) {
    return true;
  }

  // Reject unknown licenses to be safe
  logger.debug("Wikimedia unknown license, skipping", {license});
  return false;
}

/**
 * Extract license string for attribution.
 */
function getLicenseString(extmetadata: WikimediaImageInfo["extmetadata"]): string {
  if (extmetadata?.Copyrighted?.value === "False") {
    return "Public Domain";
  }
  return extmetadata?.LicenseShortName?.value || "Unknown";
}

/**
 * Strip HTML tags from artist/description fields.
 */
function stripHtml(html: string | undefined): string | undefined {
  if (!html) return undefined;
  return html.replace(/<[^>]*>/g, "").trim();
}

/**
 * Search Wikimedia Commons for images.
 * Only returns commercially-safe (non-NC) images.
 */
async function search(query: string, limit = 5): Promise<APISearchResult[]> {
  try {
    // Build API URL
    const url = new URL(BASE_URL);
    url.searchParams.set("action", "query");
    url.searchParams.set("generator", "search");
    url.searchParams.set("gsrnamespace", "6"); // File namespace
    url.searchParams.set("gsrsearch", `intitle:${query}`);
    url.searchParams.set("gsrlimit", String(limit * 3)); // Fetch extra for filtering
    url.searchParams.set("prop", "imageinfo");
    url.searchParams.set("iiprop", "url|extmetadata");
    url.searchParams.set("iiurlwidth", "800"); // Request 800px thumbnail
    url.searchParams.set("format", "json");

    const response = await fetch(url.toString(), {
      headers: {
        "User-Agent": USER_AGENT,
        "Api-User-Agent": USER_AGENT,
      },
    });

    if (!response.ok) {
      logger.warn("Wikimedia API error", {status: response.status});
      return [];
    }

    const data = (await response.json()) as WikimediaResponse;
    const pages = data.query?.pages;

    if (!pages) return [];

    // Build results, filtering for safe licenses
    const results: APISearchResult[] = [];

    for (const page of Object.values(pages)) {
      if (results.length >= limit) break;

      const imageInfo = page.imageinfo?.[0];
      if (!imageInfo) continue;

      // Check license is commercially safe
      if (!isCommerciallySafe(imageInfo.extmetadata)) {
        continue;
      }

      const imageUrl = imageInfo.thumburl || imageInfo.url;
      if (!imageUrl) continue;

      // Clean up title (remove "File:" prefix)
      const title = page.title.replace(/^File:/, "").replace(/\.[^.]+$/, "");

      results.push({
        source: "wikimedia",
        image_url: imageUrl,
        thumbnail_url: imageInfo.thumburl,
        title: title,
        description: stripHtml(imageInfo.extmetadata?.ImageDescription?.value),
        attribution: {
          source: "Wikimedia Commons",
          url: imageInfo.descriptionurl,
          license: getLicenseString(imageInfo.extmetadata),
          author: stripHtml(imageInfo.extmetadata?.Artist?.value),
        },
      });
    }

    logger.info("Wikimedia search completed", {query, resultCount: results.length});
    return results;
  } catch (error) {
    logger.error("Wikimedia search error", {error, query});
    return [];
  }
}

// Export as ImageAPIClient
export const wikimediaClient: ImageAPIClient = {
  name: "Wikimedia Commons",
  search,
};
