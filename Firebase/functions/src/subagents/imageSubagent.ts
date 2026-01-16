// imageSubagent.ts
// Generates ImageContent blocks from concept descriptions.
// Uses intent-aware routing to select the best source for each request.

import * as logger from "firebase-functions/logger";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {GoogleAuth} from "google-auth-library";
import {
  SubagentRequest,
  SubagentResponse,
  VisualRouterDecision,
  VisualIntent,
  ResponseMetadata,
  generateBlockId,
  currentTimestamp,
  readyResponse,
  failedResponse,
} from "./types";
import {searchAPIs, APISearchResult} from "./apis";

// Firestore collection name for the image library
const IMAGE_LIBRARY_COLLECTION = "image_library";

// Embedding configuration
const EMBEDDING_MODEL = "text-embedding-005";
const EMBEDDING_DIMENSIONS = 768;

// Similarity threshold for accepting a library match (0 = identical, 2 = opposite)
// Accept matches with distance < 0.5 (fairly similar)
const SIMILARITY_THRESHOLD = 0.5;

// Subject keywords for pre-filtering searches
const SUBJECT_KEYWORDS: Record<string, string[]> = {
  anatomy: ["heart", "lung", "muscle", "bone", "organ", "tissue", "body", "blood", "nerve"],
  biology: ["cell", "dna", "organism", "evolution", "ecosystem", "gene", "protein", "mitosis"],
  physics: ["force", "energy", "motion", "wave", "gravity", "electric", "magnetic", "quantum"],
  chemistry: ["atom", "molecule", "reaction", "bond", "element", "compound", "orbital", "ion"],
  astronomy: ["star", "planet", "galaxy", "solar", "universe", "orbit", "nebula", "comet"],
  psychology: ["brain", "behavior", "cognitive", "memory", "emotion", "neuron", "perception"],
};

// Intent-specific terms to enhance query text
const INTENT_TERMS: Record<string, string> = {
  show_structure: "labeled diagram structure parts components",
  show_process: "process steps sequence cycle pathway",
  show_relationship: "relationship between connection interaction",
  show_example: "example instance demonstration",
  real_world: "photograph real world actual",
  historical: "historical photo primary source",
  comparison: "comparison differences similarities versus",
  analogy: "analogy metaphor visual representation",
};

// Placeholder image URLs for fallback
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

// Library search result interface
interface LibrarySearchResult {
  id: string;
  source_url: string;
  alt_text: string;
  caption: string;
  figure_number: string;
  book_title: string;
  attribution: {
    source: string;
    book_title: string;
    url: string;
    license: string;
    license_url: string;
  };
  similarity: number;
}

/**
 * Determines if external APIs should be searched before the curated library.
 * Real-world photos and historical images are better served by external APIs.
 * Educational diagrams are better served by the curated OpenStax library.
 */
function shouldPrioritizeAPIs(intent: string, concept: string): boolean {
  // These intents want real photos, not diagrams
  const apiFirstIntents = ["real_world", "historical"];
  if (apiFirstIntents.includes(intent)) {
    return true;
  }

  // Concept-based routing
  const text = concept.toLowerCase();

  // Art/paintings → Museums have actual artwork
  if (text.includes("painting") || text.includes("artwork") || text.includes("sculpture") ||
      text.includes("portrait") || text.includes("masterpiece")) {
    return true;
  }

  // Molecules → PubChem has actual molecular structures
  if (text.includes("molecule") || text.includes("molecular structure") ||
      text.includes("compound structure") || text.includes("chemical structure")) {
    return true;
  }

  // Space photography → NASA has actual photos
  if ((text.includes("photograph") || text.includes("photo") || text.includes("image")) &&
      (text.includes("mars") || text.includes("jupiter") || text.includes("saturn") ||
       text.includes("moon") || text.includes("earth") || text.includes("space"))) {
    return true;
  }

  // Default: OpenStax first for educational content
  return false;
}

/**
 * Executes image generation subagent.
 * Uses intent-aware routing to determine search order.
 */
export async function executeImageSubagent(
  request: SubagentRequest,
  apiKey: string,
  decision: VisualRouterDecision
): Promise<SubagentResponse> {
  const startTime = Date.now();
  const intent = request.intent || "";

  // Determine search order based on intent
  const apisFirst = shouldPrioritizeAPIs(intent, request.concept);

  logger.info("Image subagent executing", {
    concept: request.concept,
    intent: request.intent,
    apisFirst,
    recommendation: decision.specific_recommendation,
  });

  try {
    if (apisFirst) {
      // Real-world/historical → External APIs first, then library
      logger.info("Prioritizing external APIs for this request");

      const apiResult = await searchAPIs(
        request.concept,
        intent,
        request.description || ""
      );

      if (apiResult) {
        logger.info("External API search successful", {
          source: apiResult.source,
          title: apiResult.title,
        });
        return buildAPIResponse(request.id, apiResult, Date.now() - startTime);
      }

      // Fallback to library if APIs have no results
      logger.info("External APIs returned no results, trying library");
      const libraryResult = await searchLibrary(request);

      if (libraryResult) {
        logger.info("Library fallback successful", {
          documentId: libraryResult.id,
          similarity: libraryResult.similarity,
        });
        return buildLibraryResponse(request.id, libraryResult, Date.now() - startTime);
      }
    } else {
      // Educational diagrams → Library first, then APIs
      logger.info("Prioritizing curated library for this request");

      const libraryResult = await searchLibrary(request);

      if (libraryResult) {
        logger.info("Library search successful", {
          documentId: libraryResult.id,
          similarity: libraryResult.similarity,
          bookTitle: libraryResult.book_title,
        });
        return buildLibraryResponse(request.id, libraryResult, Date.now() - startTime);
      }

      // Fallback to APIs if library has no results
      logger.info("Library returned no results, trying external APIs");
      const apiResult = await searchAPIs(
        request.concept,
        intent,
        request.description || ""
      );

      if (apiResult) {
        logger.info("External API fallback successful", {
          source: apiResult.source,
          title: apiResult.title,
        });
        return buildAPIResponse(request.id, apiResult, Date.now() - startTime);
      }
    }

    // No results from either source - try AI generation if allowed
    const allowGeneration = request.constraints?.allow_ai_generation !== false;

    if (allowGeneration) {
      logger.info("No results from library or APIs, attempting AI generation");
      const generated = await generateImageWithAI(request, apiKey, Date.now() - startTime);
      if (generated) {
        return generated;
      }
    }

    logger.info("No results from library or APIs, using placeholder");
    return buildPlaceholderResponse(request, Date.now() - startTime);
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
 * Searches the image library using semantic similarity.
 */
async function searchLibrary(
  request: SubagentRequest
): Promise<LibrarySearchResult | null> {
  try {
    // Build query text from request
    const queryText = buildQueryText(request);

    // Generate query embedding
    const queryEmbedding = await generateQueryEmbedding(queryText);
    if (!queryEmbedding) {
      logger.warn("Failed to generate query embedding");
      return null;
    }

    // Infer subject for pre-filtering
    const subject = inferSubject(request.concept, request.description || "");

    // Get Firestore instance
    const db = getFirestore();

    // Build query with optional subject pre-filter
    const collection = db.collection(IMAGE_LIBRARY_COLLECTION);
    const baseQuery = subject
      ? collection.where("subject", "==", subject)
      : collection;

    // Execute vector similarity search
    // Note: findNearest requires the vector index to be created in Firestore
    const vectorQuery = baseQuery.findNearest("embedding", FieldValue.vector(queryEmbedding), {
      limit: 5,
      distanceMeasure: "COSINE",
    });

    const snapshot = await vectorQuery.get();

    if (snapshot.empty) {
      logger.info("No library results found", {subject, queryTextLength: queryText.length});
      return null;
    }

    // Find best match considering intent compatibility
    const intent = request.intent as VisualIntent;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const distance = data.vector_distance as number;

      // Check if image supports the requested intent
      const intentsSupported = data.intents_supported as string[] || [];
      const intentMatch = !intent || intentsSupported.includes(intent);

      if (intentMatch && distance < SIMILARITY_THRESHOLD) {
        return {
          id: doc.id,
          source_url: data.source_url,
          alt_text: data.alt_text,
          caption: data.caption,
          figure_number: data.figure_number,
          book_title: data.book_title,
          attribution: data.attribution,
          similarity: 1 - (distance / 2), // Convert to 0-1 similarity
        };
      }
    }

    logger.info("No matching library results above threshold", {
      resultsCount: snapshot.size,
      threshold: SIMILARITY_THRESHOLD,
    });
    return null;
  } catch (error) {
    // Log but don't throw - allow fallback to placeholder
    logger.error("Library search error", {error});
    return null;
  }
}

/**
 * Generates embedding for search query using Vertex AI.
 */
async function generateQueryEmbedding(text: string): Promise<number[] | null> {
  try {
    const project = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
    if (!project) {
      logger.error("GCP project not configured for embeddings");
      return null;
    }

    const auth = new GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/cloud-platform"],
    });

    const client = await auth.getClient();
    const accessToken = await client.getAccessToken();

    if (!accessToken.token) {
      logger.error("Failed to get access token");
      return null;
    }

    const location = "us-central1";
    const endpoint =
      `https://${location}-aiplatform.googleapis.com/v1/` +
      `projects/${project}/locations/${location}/` +
      `publishers/google/models/${EMBEDDING_MODEL}:predict`;

    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken.token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        instances: [{
          content: text,
          task_type: "RETRIEVAL_QUERY", // Query mode for search
        }],
        parameters: {
          outputDimensionality: EMBEDDING_DIMENSIONS,
        },
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      logger.error("Vertex AI embedding error", {status: response.status, error: errorText});
      return null;
    }

    const data = await response.json();
    return data.predictions?.[0]?.embeddings?.values || null;
  } catch (error) {
    logger.error("Embedding generation error", {error});
    return null;
  }
}

/**
 * Builds search query text from request.
 */
function buildQueryText(request: SubagentRequest): string {
  const parts = [request.concept];

  if (request.description) {
    parts.push(request.description);
  }

  // Add intent-specific terms
  const intent = request.intent as VisualIntent;
  if (intent && INTENT_TERMS[intent]) {
    parts.push(INTENT_TERMS[intent]);
  }

  return parts.join(" ");
}

/**
 * Infers subject from concept/description.
 */
function inferSubject(concept: string, description: string): string | null {
  const text = `${concept} ${description}`.toLowerCase();

  for (const [subject, keywords] of Object.entries(SUBJECT_KEYWORDS)) {
    if (keywords.some((kw) => text.includes(kw))) {
      return subject;
    }
  }

  return null;
}

/**
 * Builds response from library search result.
 */
function buildLibraryResponse(
  requestId: string,
  result: LibrarySearchResult,
  latencyMs: number
): SubagentResponse {
  // Build ImageContent with library source
  const imageContent = {
    source: {
      type: "library",
      library_id: result.id,
      url: result.source_url, // Include URL for direct rendering
    },
    alt_text: result.alt_text,
    caption: result.caption || `${result.figure_number} from ${result.book_title}`,
    attribution: {
      source: result.attribution.source,
      url: result.attribution.url,
      license: result.attribution.license,
    },
    sizing: {
      mode: "fit",
      max_width: 1.0,
    },
  };

  // Build complete Block
  const block = {
    id: generateBlockId(),
    type: "image" as const,
    created_at: currentTimestamp(),
    status: "ready" as const,
    content: imageContent,
  };

  // Build response metadata
  const metadata: ResponseMetadata = {
    fulfillment_method: "library_search",
    latency_ms: latencyMs,
    sources_searched: ["openstax_library"],
  };

  logger.info("Returning library image", {
    blockId: block.id,
    libraryId: result.id,
    similarity: result.similarity,
    latencyMs,
  });

  return readyResponse(requestId, block, metadata);
}

/**
 * Builds response from external API search result.
 */
function buildAPIResponse(
  requestId: string,
  result: APISearchResult,
  latencyMs: number
): SubagentResponse {
  // Build ImageContent with API source
  const imageContent = {
    source: {
      type: "api",
      api_source: result.source,
      url: result.image_url,
    },
    alt_text: result.title,
    caption: result.description || result.title,
    attribution: {
      source: result.attribution.source,
      url: result.attribution.url,
      license: result.attribution.license,
      author: result.attribution.author,
    },
    sizing: {
      mode: "fit",
      max_width: 1.0,
    },
  };

  // Build complete Block
  const block = {
    id: generateBlockId(),
    type: "image" as const,
    created_at: currentTimestamp(),
    status: "ready" as const,
    content: imageContent,
  };

  // Build response metadata
  const metadata: ResponseMetadata = {
    fulfillment_method: "api_search",
    latency_ms: latencyMs,
    sources_searched: [result.source],
  };

  logger.info("Returning API image", {
    blockId: block.id,
    apiSource: result.source,
    latencyMs,
  });

  return readyResponse(requestId, block, metadata);
}

/**
 * Builds placeholder response when library and API search fail.
 */
function buildPlaceholderResponse(
  request: SubagentRequest,
  latencyMs: number
): SubagentResponse {
  // Determine category from concept for placeholder selection
  const category = inferCategory(request.concept.toLowerCase());
  const placeholderUrl = PLACEHOLDER_IMAGES[category] || PLACEHOLDER_IMAGES.default;

  // Generate alt text from concept
  const altText = `Diagram illustrating ${request.concept}`;

  // Build ImageContent
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

  // Build complete Block
  const block = {
    id: generateBlockId(),
    type: "image" as const,
    created_at: currentTimestamp(),
    status: "ready" as const,
    content: imageContent,
  };

  // Build response metadata
  const metadata: ResponseMetadata = {
    fulfillment_method: "placeholder",
    latency_ms: latencyMs,
    sources_searched: ["openstax_library", "external_apis", "placeholder"],
    fallback_reason: "No matching image found in library or external APIs",
  };

  logger.info("Returning placeholder image", {
    blockId: block.id,
    category,
    latencyMs,
  });

  return readyResponse(request.id, block, metadata);
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

/**
 * Generates an image using AI when library and API searches fail.
 * Uses Gemini 2.5 Flash image generation model.
 */
async function generateImageWithAI(
  request: SubagentRequest,
  apiKey: string,
  elapsedMs: number
): Promise<SubagentResponse | null> {
  try {
    // Build generation prompt from request
    const prompt = buildGenerationPrompt(request);

    logger.info("Calling Gemini image generation", {
      concept: request.concept,
      promptLength: prompt.length,
    });

    // Call Gemini image generation API
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({
          contents: [{
            role: "user",
            parts: [{text: prompt}],
          }],
          generationConfig: {
            responseModalities: ["image", "text"],
            responseMimeType: "text/plain",
          },
        }),
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      logger.warn("Gemini image generation failed", {
        status: response.status,
        error: errorText,
      });
      return null;
    }

    const data = await response.json();
    const parts = data.candidates?.[0]?.content?.parts;

    if (!parts || parts.length === 0) {
      logger.warn("No parts in Gemini response");
      return null;
    }

    // Find image part in response
    const imagePart = parts.find((p: {inlineData?: {mimeType: string; data: string}}) =>
      p.inlineData?.mimeType?.startsWith("image/")
    );

    if (!imagePart?.inlineData) {
      logger.warn("No image in Gemini response");
      return null;
    }

    // Build data URL from base64 image
    const imageUrl = `data:${imagePart.inlineData.mimeType};base64,${imagePart.inlineData.data}`;

    // Build ImageContent with generated source
    const imageContent = {
      source: {
        type: "generated",
        prompt: prompt,
        url: imageUrl,
      },
      alt_text: `AI-generated illustration of ${request.concept}`,
      caption: request.description || `Visual representation of ${request.concept}`,
      attribution: {
        source: "AI Generated",
        author: "Gemini 2.5 Flash",
        license: "Generated for educational use",
      },
      sizing: {
        mode: "fit",
        max_width: 1.0,
      },
    };

    // Build complete Block
    const block = {
      id: generateBlockId(),
      type: "image" as const,
      created_at: currentTimestamp(),
      status: "ready" as const,
      content: imageContent,
    };

    // Build response metadata
    const metadata: ResponseMetadata = {
      fulfillment_method: "ai_generation",
      latency_ms: Date.now() - (Date.now() - elapsedMs),
      sources_searched: ["openstax_library", "external_apis"],
      fallback_reason: "No matching image found in library or external APIs",
    };

    logger.info("Returning AI-generated image", {
      blockId: block.id,
      latencyMs: metadata.latency_ms,
    });

    return readyResponse(request.id, block, metadata);
  } catch (error) {
    logger.error("AI image generation error", {error});
    return null;
  }
}

/**
 * Builds a generation prompt from the request.
 */
function buildGenerationPrompt(request: SubagentRequest): string {
  const parts = [
    "Create an educational illustration for:",
    `Concept: ${request.concept}`,
  ];

  if (request.description) {
    parts.push(`Description: ${request.description}`);
  }

  const intent = request.intent;
  if (intent === "analogy") {
    parts.push("Style: Visual metaphor or analogy to aid understanding");
  } else if (intent === "show_structure") {
    parts.push("Style: Clear labeled diagram showing structure and parts");
  } else if (intent === "show_process") {
    parts.push("Style: Sequential illustration showing steps or stages");
  } else {
    parts.push("Style: Clear, educational illustration suitable for learning");
  }

  parts.push("Make it visually clear, educational, and easy to understand.");

  return parts.join("\n");
}
