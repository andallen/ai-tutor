// tableSubagent.ts
// Generates TableContent blocks from concept descriptions.
// Uses Gemini to infer column structure and populate data.

import * as logger from "firebase-functions/logger";
import {
  SubagentRequest,
  SubagentResponse,
  ResponseMetadata,
  generateBlockId,
  currentTimestamp,
  readyResponse,
  failedResponse,
} from "./types";

// System prompt for table generation.
const TABLE_GENERATION_PROMPT = `You generate educational table data for a tutoring application.
Given a concept and description, create a TableContent JSON object.

Output format (JSON only, no markdown):
{
  "columns": [
    {
      "id": "col1",
      "header": "Column Header",
      "width": "auto",
      "alignment": "leading",
      "data_type": "text"
    }
  ],
  "rows": [
    {
      "cells": {
        "col1": "cell value"
      },
      "highlight": false
    }
  ],
  "caption": "Optional table caption",
  "style": {
    "striped": true,
    "bordered": true,
    "compact": false,
    "header_style": "prominent"
  }
}

Rules:
- Column data_type can be: "text", "number", "date", "latex"
- Alignment can be: "leading", "center", "trailing"
- Cell values are usually strings, but can be objects: { "value": 42, "display": "42 kg" }
- For math content, use LaTeX strings in cells
- Use "highlight": true for important rows
- Generate realistic, educational data appropriate for the concept
- Keep tables concise (prefer 5-15 rows unless more are needed)`;

/**
 * Executes table generation subagent.
 */
export async function executeTableSubagent(
  request: SubagentRequest,
  apiKey: string
): Promise<SubagentResponse> {
  const startTime = Date.now();

  logger.info("Table subagent executing", {
    concept: request.concept,
    intent: request.intent,
  });

  const maxRows = request.constraints?.max_rows || 20;

  const userPrompt = `Create a table for this educational context:

Concept: ${request.concept}
Intent: ${request.intent}
Description: ${request.description}
${request.parameters ? `Parameters: ${JSON.stringify(request.parameters)}` : ""}
Maximum rows: ${maxRows}

Generate the TableContent JSON.`;

  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({
          systemInstruction: {parts: [{text: TABLE_GENERATION_PROMPT}]},
          contents: [{role: "user", parts: [{text: userPrompt}]}],
          generationConfig: {
            temperature: 0.3,
            maxOutputTokens: 4096,
          },
        }),
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      logger.error("Gemini API error in table subagent", {status: response.status, error: errorText});
      return failedResponse(
        request.id,
        "gemini_error",
        "Table generation API failed",
        {latency_ms: Date.now() - startTime}
      );
    }

    const data = await response.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!text) {
      return failedResponse(
        request.id,
        "empty_response",
        "No content generated",
        {latency_ms: Date.now() - startTime}
      );
    }

    // Parse the generated table content.
    // Handle potential markdown code blocks.
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

    const tableContent = JSON.parse(jsonText);

    // Build complete Block.
    const block = {
      id: generateBlockId(),
      type: "table" as const,
      created_at: currentTimestamp(),
      status: "ready" as const,
      content: tableContent,
    };

    // Build response metadata.
    const metadata: ResponseMetadata = {
      fulfillment_method: "render",
      latency_ms: Date.now() - startTime,
    };

    logger.info("Table subagent completed", {
      blockId: block.id,
      latencyMs: metadata.latency_ms,
    });

    return readyResponse(request.id, block, metadata);
  } catch (error) {
    logger.error("Table generation failed", {error, requestId: request.id});
    return failedResponse(
      request.id,
      "generation_failed",
      error instanceof Error ? error.message : "Unknown error",
      {latency_ms: Date.now() - startTime}
    );
  }
}

/**
 * Creates a placeholder table for testing.
 */
export function createPlaceholderTable(concept: string): object {
  return {
    columns: [
      {id: "col1", header: "Item", width: "auto", alignment: "leading", data_type: "text"},
      {id: "col2", header: "Value", width: "auto", alignment: "trailing", data_type: "number"},
    ],
    rows: [
      {cells: {col1: "Example 1", col2: "100"}, highlight: false},
      {cells: {col1: "Example 2", col2: "200"}, highlight: false},
      {cells: {col1: "Example 3", col2: "300"}, highlight: true},
    ],
    caption: `Table for: ${concept}`,
    style: {
      striped: true,
      bordered: true,
      compact: false,
      header_style: "prominent",
    },
  };
}
