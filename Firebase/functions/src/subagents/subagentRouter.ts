// subagentRouter.ts
// Unified endpoint for routing subagent requests.
// Dispatches to table, image, graphics, or embed subagents.

import {onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as logger from "firebase-functions/logger";

// Define secrets for API access
const smithsonianApiKey = defineSecret("SMITHSONIAN_API_KEY");
const googleGenaiApiKey = defineSecret("GOOGLE_GENAI_API_KEY");
import {
  SubagentRequestSchema,
  SubagentRequest,
  SubagentResponse,
  failureResponse,
} from "./types";
import {executeTableSubagent} from "./tableSubagent";
import {executeVisualRouter} from "./visualRouter";

/**
 * Main subagent execution endpoint.
 * Routes requests to appropriate subagent based on target_type.
 */
export const executeSubagent = onRequest({cors: true, maxInstances: 10, secrets: [smithsonianApiKey, googleGenaiApiKey]}, async (req, res) => {
  // Only allow POST requests.
  if (req.method !== "POST") {
    res.status(405).send({error: "Method not allowed. Use POST."});
    return;
  }

  // Validate request body.
  const parseResult = SubagentRequestSchema.safeParse(req.body);
  if (!parseResult.success) {
    const requestId = req.body?.id || "unknown";
    res.status(400).send(failureResponse(
      requestId,
      "invalid_request",
      `Invalid request: ${parseResult.error.message}`
    ));
    return;
  }

  const request: SubagentRequest = parseResult.data;
  logger.info("Subagent request received", {
    id: request.id,
    targetType: request.target_type,
    concept: request.concept,
  });

  // Get API key for Gemini calls.
  const apiKey = process.env.GOOGLE_GENAI_API_KEY;
  if (!apiKey) {
    logger.error("GOOGLE_GENAI_API_KEY not configured");
    res.status(500).send(failureResponse(
      request.id,
      "config_error",
      "API key not configured"
    ));
    return;
  }

  try {
    let response: SubagentResponse;

    switch (request.target_type) {
    case "table":
      response = await executeTableSubagent(request, apiKey);
      break;
    case "visual":
      response = await executeVisualRouter(request, apiKey);
      break;
    default:
      response = failureResponse(
        request.id,
        "unknown_type",
          `Unknown target type: ${request.target_type}`
      );
    }

    res.status(200).send(response);
  } catch (error) {
    logger.error("Subagent execution failed", {error, requestId: request.id});
    res.status(500).send(failureResponse(
      request.id,
      "execution_failed",
      error instanceof Error ? error.message : "Unknown error"
    ));
  }
});

/**
 * Batch subagent execution endpoint.
 * Processes multiple requests in parallel.
 */
export const executeSubagentBatch = onRequest({cors: true, maxInstances: 10, secrets: [smithsonianApiKey, googleGenaiApiKey]}, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send({error: "Method not allowed. Use POST."});
    return;
  }

  const requestsRaw = req.body?.requests;
  if (!Array.isArray(requestsRaw)) {
    res.status(400).send({error: "Invalid request: 'requests' must be an array"});
    return;
  }

  const apiKey = process.env.GOOGLE_GENAI_API_KEY;
  if (!apiKey) {
    res.status(500).send({error: "API key not configured"});
    return;
  }

  // Validate all requests.
  const validRequests: SubagentRequest[] = [];
  const invalidResponses: SubagentResponse[] = [];

  for (const raw of requestsRaw) {
    const parseResult = SubagentRequestSchema.safeParse(raw);
    if (parseResult.success) {
      validRequests.push(parseResult.data);
    } else {
      invalidResponses.push(failureResponse(
        raw?.id || "unknown",
        "invalid_request",
        parseResult.error.message
      ));
    }
  }

  // Process valid requests in parallel.
  const results = await Promise.all(
    validRequests.map(async (request) => {
      try {
        switch (request.target_type) {
        case "table":
          return executeTableSubagent(request, apiKey);
        case "visual":
          return executeVisualRouter(request, apiKey);
        default:
          return failureResponse(request.id, "unknown_type", `Unknown type: ${request.target_type}`);
        }
      } catch (error) {
        return failureResponse(
          request.id,
          "execution_failed",
          error instanceof Error ? error.message : "Unknown error"
        );
      }
    })
  );

  // Combine results.
  const allResponses = [...invalidResponses, ...results];

  res.status(200).send({
    responses: allResponses,
    total: allResponses.length,
    successful: allResponses.filter((r) => r.status === "ready").length,
  });
});
