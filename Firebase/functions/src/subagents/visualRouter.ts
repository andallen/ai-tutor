// visualRouter.ts
// Routes visual requests to image, graphics, or embed subagents.
// Uses intent-based routing with LLM fallback for ambiguous cases.

import * as logger from "firebase-functions/logger";
import {
  SubagentRequest,
  SubagentResponse,
  VisualRouterDecision,
  VisualIntent,
  failedResponse,
} from "./types";
import {executeImageSubagent} from "./imageSubagent";
import {executeGraphicsSubagent} from "./graphicsSubagent";
import {executeEmbedSubagent} from "./embedSubagent";

// System prompt for visual routing (used as fallback for ambiguous cases).
const VISUAL_ROUTER_PROMPT = `You route visual content requests to the appropriate renderer.
Given a request, determine the best type:

1. IMAGE: Static images, diagrams, photos, illustrations
   - Anatomy diagrams, historical photos, scientific illustrations
   - Artwork, maps, specimen images
   - Real-world examples, analogies
   - When a static representation is sufficient

2. GRAPHICS: Interactive visualizations rendered with JavaScript
   - Charts and graphs (Chart.js): line, bar, pie, scatter, area
   - Physics animations (p5.js): projectiles, pendulums, waves, forces
   - 3D visualizations (Three.js): molecules, surfaces, vector fields
   - Interactive geometry (JSXGraph): constructions, function graphs
   - Worked examples with diagrams

3. EMBED: External interactive tools
   - PhET: physics simulations (projectile-motion, gravity-force-lab, circuit-construction-kit)
   - GeoGebra: graphing calculator, geometry tools, 3D graphing
   - Desmos: advanced graphing calculator
   - YouTube: educational videos
   - CircuitJS: circuit simulations
   - When student needs to interactively explore concepts

Respond with JSON only:
{
  "selected_type": "image" | "graphics" | "embed",
  "reasoning": "Brief explanation",
  "specific_recommendation": "e.g., 'chartjs line chart' or 'phet projectile-motion'"
}`;

/**
 * Routes visual request to appropriate subagent.
 * Uses intent-based routing with LLM fallback for ambiguous cases.
 */
export async function executeVisualRouter(
  request: SubagentRequest,
  apiKey: string
): Promise<SubagentResponse> {
  logger.info("Visual router processing", {
    concept: request.concept,
    intent: request.intent,
    preferredEngine: request.constraints?.preferred_engine,
    preferredProvider: request.constraints?.preferred_provider,
    preferredFormat: request.constraints?.preferred_format,
  });

  // First, check for explicit user preferences.
  if (request.constraints?.preferred_engine) {
    const engine = request.constraints.preferred_engine.toLowerCase();
    if (["chartjs", "p5", "three", "jsxgraph", "plotly"].includes(engine)) {
      logger.info("Using preferred engine", {engine});
      const decision: VisualRouterDecision = {
        selected_type: "graphics",
        reasoning: `User specified preferred engine: ${engine}`,
        specific_recommendation: engine,
      };
      return executeGraphicsSubagent(request, apiKey, decision);
    }
  }

  if (request.constraints?.preferred_provider) {
    const provider = request.constraints.preferred_provider.toLowerCase();
    if (["phet", "geogebra", "desmos", "youtube", "circuitjs"].includes(provider)) {
      logger.info("Using preferred provider", {provider});
      const decision: VisualRouterDecision = {
        selected_type: "embed",
        reasoning: `User specified preferred provider: ${provider}`,
        specific_recommendation: provider,
      };
      return executeEmbedSubagent(request, apiKey, decision);
    }
  }

  // Second, try intent-based routing for fast deterministic decisions.
  const intentDecision = routeByIntent(request);
  if (intentDecision) {
    logger.info("Intent-based routing decision", intentDecision);
    return executeDecision(request, apiKey, intentDecision);
  }

  // Fall back to LLM for ambiguous cases.
  try {
    const decision = await routeVisualType(request, apiKey);
    logger.info("LLM routing decision", decision);
    return executeDecision(request, apiKey, decision);
  } catch (error) {
    logger.error("Visual routing failed", {error, requestId: request.id});
    return failedResponse(
      request.id,
      "routing_error",
      error instanceof Error ? error.message : "Unknown error"
    );
  }
}

/**
 * Executes the appropriate subagent based on the routing decision.
 */
async function executeDecision(
  request: SubagentRequest,
  apiKey: string,
  decision: VisualRouterDecision
): Promise<SubagentResponse> {
  switch (decision.selected_type) {
  case "image":
    return executeImageSubagent(request, apiKey, decision);
  case "graphics":
    return executeGraphicsSubagent(request, apiKey, decision);
  case "embed":
    return executeEmbedSubagent(request, apiKey, decision);
  default:
    return failedResponse(request.id, "routing_failed", "Could not determine visual type");
  }
}

/**
 * Routes based on intent enum for fast deterministic decisions.
 * Returns null if intent doesn't map to a clear routing decision.
 */
function routeByIntent(request: SubagentRequest): VisualRouterDecision | null {
  const intent = request.intent as VisualIntent;
  const concept = request.concept.toLowerCase();
  const description = request.description.toLowerCase();
  const hasParameters = !!request.parameters;

  // Interactive exploration always routes to embed.
  if (intent === "interactive_exploration") {
    return {
      selected_type: "embed",
      reasoning: "interactive_exploration intent requires simulation",
      specific_recommendation: inferEmbedProvider(concept, description),
    };
  }

  // Historical and real-world always route to image.
  if (intent === "historical" || intent === "real_world") {
    return {
      selected_type: "image",
      reasoning: `${intent} intent best served by photos/images`,
      specific_recommendation: intent === "historical" ? "library of congress" : "api search",
    };
  }

  // Analogy usually needs image (may fall back to AI generation).
  if (intent === "analogy") {
    return {
      selected_type: "image",
      reasoning: "analogy intent needs visual metaphor image",
      specific_recommendation: "ai generation if needed",
    };
  }

  // Show structure with anatomical/scientific terms routes to image.
  if (intent === "show_structure") {
    const anatomicalTerms = ["cell", "organ", "anatomy", "body", "structure", "diagram",
      "mitochondria", "nucleus", "membrane", "tissue"];
    if (anatomicalTerms.some((term) => concept.includes(term) || description.includes(term))) {
      return {
        selected_type: "image",
        reasoning: "show_structure with anatomical concept best served by diagram",
        specific_recommendation: "openstax diagram",
      };
    }
  }

  // Worked example with physics concepts routes to graphics.
  if (intent === "worked_example") {
    const physicsTerms = ["force", "free body", "vector", "projectile", "motion", "diagram"];
    if (physicsTerms.some((term) => concept.includes(term) || description.includes(term))) {
      return {
        selected_type: "graphics",
        reasoning: "worked_example with physics concept needs rendered diagram",
        specific_recommendation: "p5 force diagram",
      };
    }
    // Geometry worked example.
    const geometryTerms = ["triangle", "circle", "angle", "polygon", "geometry"];
    if (geometryTerms.some((term) => concept.includes(term) || description.includes(term))) {
      return {
        selected_type: "graphics",
        reasoning: "worked_example with geometry needs interactive construction",
        specific_recommendation: "jsxgraph",
      };
    }
  }

  // Show relationship with chart data or parameters routes to graphics.
  if (intent === "show_relationship") {
    if (hasParameters || concept.includes("graph") || concept.includes("chart") ||
        description.includes("plot") || description.includes("data")) {
      return {
        selected_type: "graphics",
        reasoning: "show_relationship with data best served by chart",
        specific_recommendation: "chartjs",
      };
    }
  }

  // Show process may route to graphics for animations.
  if (intent === "show_process") {
    const animationTerms = ["animation", "motion", "cycle", "sequence", "wave", "oscillation"];
    if (animationTerms.some((term) => concept.includes(term) || description.includes(term))) {
      return {
        selected_type: "graphics",
        reasoning: "show_process with motion concept needs animation",
        specific_recommendation: "p5",
      };
    }
  }

  // Comparison may route to graphics for side-by-side charts.
  if (intent === "comparison" && hasParameters) {
    return {
      selected_type: "graphics",
      reasoning: "comparison with parameters best served by chart",
      specific_recommendation: "chartjs bar chart",
    };
  }

  // No clear intent-based decision - return null to use LLM.
  return null;
}

/**
 * Infers the best embed provider from concept and description.
 */
function inferEmbedProvider(concept: string, description: string): string {
  const text = `${concept} ${description}`.toLowerCase();

  // Physics simulations.
  if (text.includes("projectile") || text.includes("gravity") || text.includes("pendulum") ||
      text.includes("energy") || text.includes("wave") || text.includes("force")) {
    return "phet";
  }

  // Circuit simulations.
  if (text.includes("circuit") || text.includes("resistor") || text.includes("capacitor")) {
    return text.includes("phet") ? "phet" : "circuitjs";
  }

  // Graphing.
  if (text.includes("graph") || text.includes("function") || text.includes("equation")) {
    return text.includes("geogebra") ? "geogebra" : "desmos";
  }

  // Geometry.
  if (text.includes("geometry") || text.includes("construction") || text.includes("triangle")) {
    return "geogebra geometry";
  }

  // Default to PhET.
  return "phet";
}

/**
 * Determines the visual type using LLM (fallback for ambiguous cases).
 */
async function routeVisualType(
  request: SubagentRequest,
  apiKey: string
): Promise<VisualRouterDecision> {
  const userPrompt = `Route this visual content request:

Concept: ${request.concept}
Intent: ${request.intent}
Description: ${request.description}
${request.parameters ? `Parameters provided: ${JSON.stringify(request.parameters)}` : "No parameters"}

Determine the best visual type (image, graphics, or embed).`;

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({
        systemInstruction: {parts: [{text: VISUAL_ROUTER_PROMPT}]},
        contents: [{role: "user", parts: [{text: userPrompt}]}],
        generationConfig: {
          temperature: 0.2,
          maxOutputTokens: 256,
        },
      }),
    }
  );

  if (!response.ok) {
    logger.warn("Visual router LLM call failed, defaulting to image");
    return {
      selected_type: "image",
      reasoning: "Defaulting to image due to routing failure (most flexible)",
      specific_recommendation: "placeholder",
    };
  }

  const data = await response.json();
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;

  if (!text) {
    return {
      selected_type: "image",
      reasoning: "Empty response, defaulting to image",
      specific_recommendation: "placeholder",
    };
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

  try {
    const decision = JSON.parse(jsonText) as VisualRouterDecision;

    // Validate selected_type.
    if (!["image", "graphics", "embed"].includes(decision.selected_type)) {
      decision.selected_type = "image";
    }

    return decision;
  } catch {
    logger.warn("Failed to parse routing decision, defaulting to image");
    return {
      selected_type: "image",
      reasoning: "Parse error, defaulting to image (most flexible)",
      specific_recommendation: "placeholder",
    };
  }
}
