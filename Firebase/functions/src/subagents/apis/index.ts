// index.ts
// API router for external image search.
// Selects appropriate APIs based on intent/concept and searches in parallel.

import * as logger from "firebase-functions/logger";
import {APISearchResult, ImageAPIClient} from "./types";
import {nasaClient} from "./nasa";
import {pubchemClient} from "./pubchem";
// LOC import removed from active use - Cloudflare bot protection blocks API access
import {metMuseumClient} from "./metMuseum";
import {artInstituteClient} from "./artInstituteChicago";
import {wikimediaClient} from "./wikimedia";
import {smithsonianClient} from "./smithsonian";

// Re-export types
export {APISearchResult, ImageAPIClient} from "./types";

// Re-export individual clients for direct access
export {nasaClient} from "./nasa";
export {pubchemClient} from "./pubchem";
export {locClient} from "./libraryOfCongress";
export {metMuseumClient} from "./metMuseum";
export {artInstituteClient} from "./artInstituteChicago";
export {wikimediaClient} from "./wikimedia";
export {smithsonianClient} from "./smithsonian";

/**
 * Select which APIs to query based on request context.
 * Returns a prioritized list of API clients.
 */
export function selectAPIs(
  concept: string,
  intent: string,
  description: string
): ImageAPIClient[] {
  const apis: ImageAPIClient[] = [];
  const text = `${concept} ${description}`.toLowerCase();

  // Intent-based routing (highest priority)
  // Note: LOC is excluded due to Cloudflare bot protection blocking API access
  if (intent === "historical") {
    apis.push(smithsonianClient, nasaClient, wikimediaClient);
  } else if (intent === "real_world") {
    apis.push(nasaClient, smithsonianClient, wikimediaClient);
  }

  // Concept-based routing

  // Chemistry/molecules → PubChem
  if (
    text.includes("molecule") ||
    text.includes("compound") ||
    text.includes("chemical") ||
    text.includes("structure") && (text.includes("atom") || text.includes("bond"))
  ) {
    apis.push(pubchemClient);
  }

  // Art/paintings → Museums
  if (
    text.includes("art") ||
    text.includes("painting") ||
    text.includes("sculpture") ||
    text.includes("artwork") ||
    text.includes("portrait") ||
    text.includes("artist")
  ) {
    apis.push(metMuseumClient, artInstituteClient);
  }

  // Space/astronomy → NASA
  if (
    text.includes("space") ||
    text.includes("planet") ||
    text.includes("galaxy") ||
    text.includes("star") ||
    text.includes("nebula") ||
    text.includes("asteroid") ||
    text.includes("comet") ||
    text.includes("solar") ||
    text.includes("moon") ||
    text.includes("mars") ||
    text.includes("jupiter") ||
    text.includes("saturn") ||
    text.includes("telescope") ||
    text.includes("astronaut") ||
    text.includes("rocket") ||
    text.includes("nasa")
  ) {
    apis.push(nasaClient);
  }

  // Nature/biology → Smithsonian
  if (
    text.includes("animal") ||
    text.includes("plant") ||
    text.includes("specimen") ||
    text.includes("insect") ||
    text.includes("bird") ||
    text.includes("fish") ||
    text.includes("mammal") ||
    text.includes("reptile") ||
    text.includes("fossil") ||
    text.includes("mineral") ||
    text.includes("nature") ||
    text.includes("wildlife")
  ) {
    apis.push(smithsonianClient);
  }

  // History/culture → Smithsonian, Wikimedia
  // (LOC excluded due to Cloudflare protection)
  if (
    text.includes("history") ||
    text.includes("historical") ||
    text.includes("war") ||
    text.includes("ancient") ||
    text.includes("century") ||
    text.includes("civilization") ||
    text.includes("revolution") ||
    text.includes("president") ||
    text.includes("photograph") && text.includes("old")
  ) {
    apis.push(smithsonianClient, wikimediaClient);
  }

  // Earth science → NASA
  if (
    text.includes("earth") ||
    text.includes("climate") ||
    text.includes("weather") ||
    text.includes("satellite") ||
    text.includes("ocean") && text.includes("view")
  ) {
    apis.push(nasaClient);
  }

  // Default fallback: Wikimedia (most general)
  if (apis.length === 0) {
    apis.push(wikimediaClient);
  }

  // Deduplicate while preserving order
  const seen = new Set<string>();
  return apis.filter((api) => {
    if (seen.has(api.name)) return false;
    seen.add(api.name);
    return true;
  });
}

/**
 * Search selected APIs in parallel and return the best result.
 * Queries all selected APIs simultaneously for speed.
 */
export async function searchAPIs(
  concept: string,
  intent: string,
  description: string
): Promise<APISearchResult | null> {
  const apis = selectAPIs(concept, intent, description);

  if (apis.length === 0) {
    logger.info("No APIs selected for query");
    return null;
  }

  // Build search query
  const query = description ? `${concept} ${description}` : concept;

  logger.info("Searching external APIs", {
    query,
    intent,
    apis: apis.map((a) => a.name),
  });

  // Search all APIs in parallel
  const results = await Promise.allSettled(
    apis.map((api) => api.search(query, 3))
  );

  // Collect all successful results
  const allResults: APISearchResult[] = [];

  for (let i = 0; i < results.length; i++) {
    const result = results[i];
    const apiName = apis[i].name;

    if (result.status === "fulfilled") {
      const apiResults = result.value.filter((r) => r.image_url);
      if (apiResults.length > 0) {
        logger.info("API returned results", {api: apiName, count: apiResults.length});
        allResults.push(...apiResults);
      } else {
        logger.info("API returned no valid results", {api: apiName});
      }
    } else {
      logger.warn("API search failed", {api: apiName, error: result.reason});
    }
  }

  if (allResults.length === 0) {
    logger.info("No results from any API", {query, apis: apis.map((a) => a.name)});
    return null;
  }

  // Return first valid result (APIs are already priority-ordered)
  const best = allResults[0];
  logger.info("Selected API result", {
    source: best.source,
    title: best.title,
    totalResults: allResults.length,
  });

  return best;
}
