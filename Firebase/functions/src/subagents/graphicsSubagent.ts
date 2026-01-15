// graphicsSubagent.ts
// Generates GraphicsContent blocks from concept descriptions.
// Supports Chart.js, p5.js, Three.js, JSXGraph, and Plotly.

import * as logger from "firebase-functions/logger";
import {
  SubagentRequest,
  SubagentResponse,
  VisualRouterDecision,
  ResponseMetadata,
  generateBlockId,
  currentTimestamp,
  readyResponse,
} from "./types";

// System prompt for graphics generation.
const GRAPHICS_GENERATION_PROMPT = `You generate JavaScript visualization specifications for educational content.
Based on the concept and description, create a GraphicsContent JSON object.

Choose the appropriate engine:
- chartjs: Simple 2D charts (line, bar, pie, scatter, area)
- p5: Physics simulations, animations, interactive diagrams
- three: 3D visualizations (molecules, surfaces, vector fields)
- jsxgraph: Interactive geometry, function graphing
- plotly: Complex or 3D charts

Output format (JSON only):
{
  "engine": "chartjs" | "p5" | "three" | "jsxgraph" | "plotly",
  "spec": {
    // Engine-specific configuration
  },
  "sizing": {
    "width": "full",
    "aspect_ratio": 1.5
  },
  "caption": "Description of the visualization"
}

For Chart.js, spec should be a valid Chart.js configuration.
For p5, spec should include { "sketch": "p5 code as string" }.
For Three.js, spec should describe the 3D scene.
For JSXGraph, spec should describe the geometric construction.
For Plotly, spec should be a valid Plotly data/layout configuration.`;

/**
 * Executes graphics generation subagent.
 */
export async function executeGraphicsSubagent(
  request: SubagentRequest,
  apiKey: string,
  decision: VisualRouterDecision
): Promise<SubagentResponse> {
  const startTime = Date.now();

  logger.info("Graphics subagent executing", {
    concept: request.concept,
    intent: request.intent,
    recommendation: decision.specific_recommendation,
  });

  // Determine engine from recommendation or infer from concept.
  const engine = inferEngine(decision.specific_recommendation, request.concept);

  try {
    const userPrompt = `Create a ${engine} visualization for:

Concept: ${request.concept}
Intent: ${request.intent}
Description: ${request.description}
${request.parameters ? `Parameters: ${JSON.stringify(request.parameters)}` : ""}

Generate the GraphicsContent JSON with engine "${engine}".`;

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({
          systemInstruction: {parts: [{text: GRAPHICS_GENERATION_PROMPT}]},
          contents: [{role: "user", parts: [{text: userPrompt}]}],
          generationConfig: {
            temperature: 0.4,
            maxOutputTokens: 4096,
          },
        }),
      }
    );

    if (!response.ok) {
      logger.warn("Graphics generation API failed, using placeholder");
      return createPlaceholderGraphics(request, engine, startTime, "API request failed");
    }

    const data = await response.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!text) {
      return createPlaceholderGraphics(request, engine, startTime, "Empty response from API");
    }

    // Parse JSON response.
    let jsonText = text.trim();
    if (jsonText.startsWith("```json")) {
      jsonText = jsonText.slice(7);
    }
    if (jsonText.startsWith("```")) {
      jsonText = jsonText.slice(3);
    }
    if (jsonText.endsWith("```")) {
      jsonText = jsonText.slice(0, -3);
    }
    jsonText = jsonText.trim();

    const graphicsContent = JSON.parse(jsonText);

    // Ensure engine is set.
    if (!graphicsContent.engine) {
      graphicsContent.engine = engine;
    }

    // Build complete Block.
    const block = {
      id: generateBlockId(),
      type: "graphics" as const,
      created_at: currentTimestamp(),
      status: "ready" as const,
      content: graphicsContent,
    };

    // Build response metadata.
    const metadata: ResponseMetadata = {
      fulfillment_method: "render",
      latency_ms: Date.now() - startTime,
      engine_selected: engine,
    };

    logger.info("Graphics subagent completed", {
      blockId: block.id,
      engine,
      latencyMs: metadata.latency_ms,
    });

    return readyResponse(request.id, block, metadata);
  } catch (error) {
    logger.error("Graphics generation failed", {error, requestId: request.id});
    return createPlaceholderGraphics(
      request,
      engine,
      startTime,
      error instanceof Error ? error.message : "Unknown error"
    );
  }
}

/**
 * Infers the appropriate graphics engine from recommendation or concept.
 */
function inferEngine(recommendation: string | undefined, concept: string): string {
  if (recommendation) {
    const rec = recommendation.toLowerCase();
    if (rec.includes("chartjs") || rec.includes("chart.js") || rec.includes("chart")) {
      return "chartjs";
    }
    if (rec.includes("p5") || rec.includes("animation") || rec.includes("simulation")) {
      return "p5";
    }
    if (rec.includes("three") || rec.includes("3d")) {
      return "three";
    }
    if (rec.includes("jsx") || rec.includes("geometry")) {
      return "jsxgraph";
    }
    if (rec.includes("plotly")) {
      return "plotly";
    }
  }

  // Infer from concept.
  const c = concept.toLowerCase();
  if (c.includes("graph") || c.includes("plot") || c.includes("chart") ||
      c.includes("data") || c.includes("statistics")) {
    return "chartjs";
  }
  if (c.includes("projectile") || c.includes("pendulum") || c.includes("wave") ||
      c.includes("force") || c.includes("motion") || c.includes("physics")) {
    return "p5";
  }
  if (c.includes("molecule") || c.includes("3d") || c.includes("surface") ||
      c.includes("vector field") || c.includes("rotation")) {
    return "three";
  }
  if (c.includes("geometry") || c.includes("triangle") || c.includes("circle") ||
      c.includes("construction") || c.includes("angle")) {
    return "jsxgraph";
  }

  return "chartjs"; // Default.
}

/**
 * Creates a placeholder graphics block when generation fails.
 */
function createPlaceholderGraphics(
  request: SubagentRequest,
  engine: string,
  startTime: number,
  fallbackReason: string
): SubagentResponse {
  let graphicsContent: object;

  switch (engine) {
  case "chartjs":
    graphicsContent = {
      engine: "chartjs",
      spec: {
        type: "line",
        data: {
          labels: ["A", "B", "C", "D", "E"],
          datasets: [{
            label: request.concept,
            data: [10, 20, 15, 30, 25],
            borderColor: "#2196F3",
            backgroundColor: "rgba(33, 150, 243, 0.1)",
          }],
        },
        options: {
          responsive: true,
          plugins: {
            title: {
              display: true,
              text: `Chart: ${request.concept}`,
            },
          },
        },
      },
      sizing: {width: "full", aspect_ratio: 1.5},
      caption: `Placeholder chart for: ${request.concept}`,
    };
    break;

  case "p5":
    graphicsContent = {
      engine: "p5",
      spec: {
        sketch: `
function setup() {
  createCanvas(400, 300);
}

function draw() {
  background(240);
  fill(33, 150, 243);
  ellipse(mouseX || width/2, mouseY || height/2, 50, 50);
  fill(0);
  textAlign(CENTER, CENTER);
  text("${request.concept}", width/2, 20);
}`,
      },
      sizing: {width: "full", aspect_ratio: 1.33},
      caption: `Placeholder animation for: ${request.concept}`,
    };
    break;

  default:
    graphicsContent = {
      engine: "chartjs",
      spec: {
        type: "bar",
        data: {
          labels: ["Category 1", "Category 2", "Category 3"],
          datasets: [{
            label: request.concept,
            data: [30, 50, 40],
            backgroundColor: ["#4CAF50", "#2196F3", "#FF9800"],
          }],
        },
      },
      sizing: {width: "full", aspect_ratio: 1.5},
      caption: `Placeholder visualization for: ${request.concept}`,
    };
  }

  const block = {
    id: generateBlockId(),
    type: "graphics" as const,
    created_at: currentTimestamp(),
    status: "ready" as const,
    content: graphicsContent,
  };

  // Build response metadata with fallback info.
  const metadata: ResponseMetadata = {
    fulfillment_method: "render",
    latency_ms: Date.now() - startTime,
    engine_selected: engine,
    fallback_reason: fallbackReason,
  };

  return readyResponse(request.id, block, metadata);
}
