// embedSubagent.ts
// Generates EmbedContent blocks for interactive external tools.
// Supports PhET, GeoGebra, Desmos, CircuitJS, and YouTube.

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

// Known PhET simulations with their IDs.
const PHET_SIMULATIONS: Record<string, string> = {
  "projectile motion": "projectile-motion",
  "projectile": "projectile-motion",
  "gravity": "gravity-force-lab",
  "gravity force": "gravity-force-lab",
  "forces": "forces-and-motion-basics",
  "friction": "friction",
  "pendulum": "pendulum-lab",
  "wave": "wave-on-a-string",
  "waves": "wave-interference",
  "sound": "sound",
  "circuit": "circuit-construction-kit-dc",
  "circuits": "circuit-construction-kit-dc",
  "resistance": "resistance-in-a-wire",
  "ohms law": "ohms-law",
  "energy": "energy-skate-park-basics",
  "skate park": "energy-skate-park",
  "atom": "build-an-atom",
  "molecule": "molecule-shapes",
  "states of matter": "states-of-matter-basics",
  "ph scale": "ph-scale",
  "concentration": "concentration",
  "balancing equations": "balancing-chemical-equations",
  "area": "area-model-algebra",
  "fractions": "fractions-intro",
  "graphing": "graphing-lines",
  "quadratics": "graphing-quadratics",
  "trig": "trig-tour",
  "natural selection": "natural-selection",
  "gene expression": "gene-expression-essentials",
};

// Known GeoGebra resources.
const GEOGEBRA_RESOURCES: Record<string, string> = {
  "graphing": "graphing",
  "calculator": "graphing",
  "geometry": "geometry",
  "3d": "3d",
  "cas": "cas",
  "spreadsheet": "spreadsheet",
};

/**
 * Executes embed generation subagent.
 */
export async function executeEmbedSubagent(
  request: SubagentRequest,
  apiKey: string,
  decision: VisualRouterDecision
): Promise<SubagentResponse> {
  const startTime = Date.now();

  logger.info("Embed subagent executing", {
    concept: request.concept,
    intent: request.intent,
    recommendation: decision.specific_recommendation,
  });

  try {
    // Determine provider and configuration.
    const {provider, config, simulationMatched} = inferEmbed(
      request.concept,
      request.description,
      decision.specific_recommendation
    );

    // Build EmbedContent.
    const embedContent: Record<string, unknown> = {
      provider,
      sizing: {
        width: "full",
        aspect_ratio: 1.5,
        allow_fullscreen: true,
      },
      caption: `Interactive: ${request.concept}`,
    };

    // Add provider-specific configuration.
    switch (provider) {
    case "phet":
      embedContent.phet = config;
      break;
    case "geogebra":
      embedContent.geogebra = config;
      break;
    case "desmos":
      embedContent.desmos = config;
      break;
    case "circuitjs":
      embedContent.circuitjs = config;
      break;
    case "youtube":
      embedContent.youtube = config;
      break;
    default:
      embedContent.url = config;
    }

    // Build complete Block.
    const block = {
      id: generateBlockId(),
      type: "embed" as const,
      created_at: currentTimestamp(),
      status: "ready" as const,
      content: embedContent,
    };

    // Build response metadata.
    const metadata: ResponseMetadata = {
      fulfillment_method: "embed_match",
      latency_ms: Date.now() - startTime,
      provider,
      simulation_matched: simulationMatched,
    };

    logger.info("Embed subagent completed", {
      blockId: block.id,
      provider,
      simulationMatched,
      latencyMs: metadata.latency_ms,
    });

    return readyResponse(request.id, block, metadata);
  } catch (error) {
    logger.error("Embed generation failed", {error, requestId: request.id});
    return failedResponse(
      request.id,
      "generation_failed",
      error instanceof Error ? error.message : "Unknown error",
      {latency_ms: Date.now() - startTime}
    );
  }
}

/**
 * Infers the embed provider and configuration from concept/description.
 */
function inferEmbed(
  concept: string,
  description: string,
  recommendation: string | undefined
): {provider: string; config: Record<string, unknown>; simulationMatched?: string} {
  const searchText = `${concept} ${description} ${recommendation || ""}`.toLowerCase();

  // Check for PhET simulations.
  for (const [keyword, simId] of Object.entries(PHET_SIMULATIONS)) {
    if (searchText.includes(keyword)) {
      return {
        provider: "phet",
        config: {
          simulation_id: simId,
          language: "en",
          screen_index: 0,
        },
        simulationMatched: simId,
      };
    }
  }

  // Check for GeoGebra.
  if (searchText.includes("geogebra")) {
    let resourceType = "graphing";
    for (const [keyword, type] of Object.entries(GEOGEBRA_RESOURCES)) {
      if (searchText.includes(keyword)) {
        resourceType = type;
        break;
      }
    }
    return {
      provider: "geogebra",
      config: {
        resource_type: resourceType,
        show_toolbar: true,
        show_menu_bar: false,
        enable_right_click: false,
      },
      simulationMatched: `geogebra-${resourceType}`,
    };
  }

  // Check for Desmos.
  if (searchText.includes("desmos") || searchText.includes("graphing calculator") ||
      (searchText.includes("graph") && searchText.includes("function"))) {
    return {
      provider: "desmos",
      config: {
        calculator_type: "graphing",
        expressions: true,
        settings_menu: false,
        show_grid: true,
        show_x_axis: true,
        show_y_axis: true,
      },
      simulationMatched: "desmos-graphing",
    };
  }

  // Check for CircuitJS.
  if (searchText.includes("circuit") && !searchText.includes("phet")) {
    return {
      provider: "circuitjs",
      config: {
        show_sidebar: true,
        allow_save: false,
        euro_resistors: false,
      },
      simulationMatched: "circuitjs",
    };
  }

  // Check for YouTube.
  if (searchText.includes("video") || searchText.includes("youtube")) {
    return {
      provider: "youtube",
      config: {
        video_id: "dQw4w9WgXcQ", // Placeholder video ID.
        start_time: 0,
        autoplay: false,
        controls: true,
      },
      simulationMatched: "youtube-placeholder",
    };
  }

  // Default to PhET projectile motion as a safe fallback.
  return {
    provider: "phet",
    config: {
      simulation_id: "projectile-motion",
      language: "en",
      screen_index: 0,
    },
    simulationMatched: "projectile-motion",
  };
}
