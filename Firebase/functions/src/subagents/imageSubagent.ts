// imageSubagent.ts
// Generates ImageContent blocks from concept descriptions.
// SCAFFOLD: Returns placeholder content. Full implementation will include:
// - Curated library search (OpenStax diagrams)
// - External API queries (NASA, Smithsonian, Wikimedia, museums)
// - AI image generation fallback

import * as logger from "firebase-functions/logger";
import {
  SubagentRequest,
  SubagentResponse,
  VisualRouterDecision,
  ResponseMetadata,
  generateBlockId,
  currentTimestamp,
  readyResponse,
  failedResponse,
} from "./types";

// Placeholder image URLs for different categories.
const PLACEHOLDER_IMAGES: Record<string, string> = {
  anatomy: "https://via.placeholder.com/800x600/4CAF50/FFFFFF?text=Anatomy+Diagram",
  physics: "https://via.placeholder.com/800x600/2196F3/FFFFFF?text=Physics+Diagram",
  chemistry: "https://via.placeholder.com/800x600/9C27B0/FFFFFF?text=Chemistry+Diagram",
  biology: "https://via.placeholder.com/800x600/4CAF50/FFFFFF?text=Biology+Diagram",
  math: "https://via.placeholder.com/800x600/FF9800/FFFFFF?text=Math+Diagram",
  history: "https://via.placeholder.com/800x600/795548/FFFFFF?text=Historical+Image",
  geography: "https://via.placeholder.com/800x600/009688/FFFFFF?text=Geography+Map",
  default: "https://via.placeholder.com/800x600/607D8B/FFFFFF?text=Educational+Image",
};

/**
 * Executes image generation subagent.
 * SCAFFOLD: Returns placeholder image. Full implementation coming later.
 */
export async function executeImageSubagent(
  request: SubagentRequest,
  apiKey: string,
  decision: VisualRouterDecision
): Promise<SubagentResponse> {
  const startTime = Date.now();

  logger.info("Image subagent executing", {
    concept: request.concept,
    intent: request.intent,
    recommendation: decision.specific_recommendation,
  });

  try {
    // Determine category from concept for placeholder selection.
    const category = inferCategory(request.concept.toLowerCase());
    const placeholderUrl = PLACEHOLDER_IMAGES[category] || PLACEHOLDER_IMAGES.default;

    // Generate alt text from concept.
    const altText = `Diagram illustrating ${request.concept}`;

    // Build ImageContent.
    const imageContent = {
      source: {
        type: "url",
        url: placeholderUrl,
      },
      alt_text: altText,
      caption: `${request.concept} (placeholder image)`,
      attribution: {
        source: "Placeholder",
        author: "System Generated",
        license: "Placeholder for development",
      },
      sizing: {
        width: "full",
        aspect_ratio: 1.33,
        object_fit: "contain",
      },
    };

    // Build complete Block.
    const block = {
      id: generateBlockId(),
      type: "image" as const,
      created_at: currentTimestamp(),
      status: "ready" as const,
      content: imageContent,
    };

    // Build response metadata.
    const metadata: ResponseMetadata = {
      fulfillment_method: "library_search", // Scaffold uses placeholder as "library"
      latency_ms: Date.now() - startTime,
      sources_searched: ["placeholder"],
      fallback_reason: "Full implementation pending - using placeholder",
    };

    logger.info("Image subagent returning placeholder", {
      blockId: block.id,
      latencyMs: metadata.latency_ms,
    });

    return readyResponse(request.id, block, metadata);
  } catch (error) {
    logger.error("Image generation failed", {error, requestId: request.id});
    return failedResponse(
      request.id,
      "generation_failed",
      error instanceof Error ? error.message : "Unknown error",
      {latency_ms: Date.now() - startTime}
    );
  }
}

/**
 * Infers content category from concept for placeholder selection.
 */
function inferCategory(concept: string): string {
  if (concept.includes("heart") || concept.includes("lung") || concept.includes("body") ||
      concept.includes("organ") || concept.includes("muscle") || concept.includes("bone")) {
    return "anatomy";
  }
  if (concept.includes("force") || concept.includes("motion") || concept.includes("energy") ||
      concept.includes("wave") || concept.includes("gravity") || concept.includes("electric")) {
    return "physics";
  }
  if (concept.includes("atom") || concept.includes("molecule") || concept.includes("element") ||
      concept.includes("reaction") || concept.includes("bond") || concept.includes("compound")) {
    return "chemistry";
  }
  if (concept.includes("cell") || concept.includes("dna") || concept.includes("plant") ||
      concept.includes("animal") || concept.includes("ecosystem") || concept.includes("evolution")) {
    return "biology";
  }
  if (concept.includes("graph") || concept.includes("equation") || concept.includes("function") ||
      concept.includes("geometry") || concept.includes("algebra") || concept.includes("calculus")) {
    return "math";
  }
  if (concept.includes("war") || concept.includes("ancient") || concept.includes("century") ||
      concept.includes("civilization") || concept.includes("revolution") || concept.includes("empire")) {
    return "history";
  }
  if (concept.includes("map") || concept.includes("country") || concept.includes("continent") ||
      concept.includes("ocean") || concept.includes("climate") || concept.includes("terrain")) {
    return "geography";
  }
  return "default";
}
