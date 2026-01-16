// alanAgent.ts
// Main Alan tutoring agent endpoint.
// Streams structured output via Server-Sent Events (SSE).

import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {z} from "zod";
import {ALAN_SYSTEM_PROMPT} from "./alanPrompts";
import {AlanOutputSchema, SessionModelSchema} from "./outputSchema";

// Request validation schema.
const AlanRequestSchema = z.object({
  messages: z.array(z.object({
    role: z.enum(["user", "assistant"]),
    content: z.string(),
  })),
  notebook_context: z.object({
    document_id: z.string(),
    current_blocks: z.array(z.any()).optional(),
    session_topic: z.string().optional(),
  }),
  session_model: SessionModelSchema.optional(),
});

type AlanRequest = z.infer<typeof AlanRequestSchema>;

/**
 * Main Alan tutoring agent endpoint.
 * Streams responses via SSE for real-time updates.
 */
export const alan = onRequest({cors: true, maxInstances: 10}, async (req, res) => {
  // Only allow POST requests.
  if (req.method !== "POST") {
    res.status(405).send({error: "Method not allowed. Use POST."});
    return;
  }

  // Validate request body.
  const parseResult = AlanRequestSchema.safeParse(req.body);
  if (!parseResult.success) {
    res.status(400).send({
      error: "Invalid request",
      details: parseResult.error.message,
    });
    return;
  }

  const request: AlanRequest = parseResult.data;
  logger.info("Alan request received", {
    messageCount: request.messages.length,
    documentId: request.notebook_context.document_id,
  });

  // Get API key.
  const apiKey = process.env.GOOGLE_GENAI_API_KEY;
  if (!apiKey) {
    logger.error("GOOGLE_GENAI_API_KEY not configured");
    res.status(500).send({error: "API key not configured"});
    return;
  }

  // Set SSE headers.
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.setHeader("X-Accel-Buffering", "no");

  try {
    // Build Gemini request.
    const contents = request.messages.map((m) => ({
      role: m.role === "assistant" ? "model" : "user",
      parts: [{text: m.content}],
    }));

    // Build system instruction with session model context.
    let systemPrompt = ALAN_SYSTEM_PROMPT;
    if (request.session_model) {
      systemPrompt += `\n\n## Current Session Model\n\`\`\`json\n${JSON.stringify(request.session_model, null, 2)}\n\`\`\``;
    } else {
      // First turn - provide default model structure for Alan to initialize.
      systemPrompt += `\n\n## Current Session Model\nNo session model provided. This is the first turn. Initialize a new session model with session_id: "${request.notebook_context.document_id}", turn_count: 1, goal: null, concepts: {}, signals with medium engagement/none frustration/normal pace, and empty facts array.`;
    }

    // Call Gemini with streaming.
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse&key=${apiKey}`;

    const geminiResponse = await fetch(geminiUrl, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({
        systemInstruction: {parts: [{text: systemPrompt}]},
        contents,
        generationConfig: {
          temperature: 0.7,
          topP: 0.95,
          maxOutputTokens: 8192,
        },
      }),
    });

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      logger.error("Gemini API error", {status: geminiResponse.status, error: errorText});
      res.write(`data: ${JSON.stringify({error: {code: "gemini_error", message: "Gemini API failed"}})}\n\n`);
      res.end();
      return;
    }

    // Stream response to client.
    const reader = geminiResponse.body?.getReader();
    if (!reader) {
      res.write(`data: ${JSON.stringify({error: {code: "no_body", message: "No response body"}})}\n\n`);
      res.end();
      return;
    }

    const decoder = new TextDecoder();
    let buffer = "";
    let fullText = "";

    // Process streaming response.
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, {stream: true});
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";

      for (const line of lines) {
        if (line.startsWith("data: ")) {
          const jsonStr = line.slice(6).trim();
          if (jsonStr && jsonStr !== "[DONE]") {
            try {
              const data = JSON.parse(jsonStr);
              const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
              if (text) {
                fullText += text;
                // Stream text chunks for progressive display.
                res.write(`data: ${JSON.stringify({text})}\n\n`);
              }
            } catch {
              // Skip malformed chunks.
            }
          }
        }
      }
    }

    // Parse and validate the complete response.
    try {
      const alanOutput = JSON.parse(fullText);
      const validated = AlanOutputSchema.safeParse(alanOutput);

      if (validated.success) {
        // Send each notebook update as a separate event.
        for (const update of validated.data.notebook_updates) {
          res.write(`data: ${JSON.stringify({notebook_update: update})}\n\n`);
        }
        // Send the updated session model.
        res.write(`data: ${JSON.stringify({session_model: validated.data.session_model})}\n\n`);
      } else {
        logger.warn("Alan output validation failed", {error: validated.error});
        // Still send the raw output.
        res.write(`data: ${JSON.stringify({raw_output: alanOutput})}\n\n`);
      }
    } catch {
      logger.warn("Failed to parse Alan output as JSON", {text: fullText.substring(0, 200)});
      // Send as plain text if not valid JSON.
      res.write(`data: ${JSON.stringify({text: fullText})}\n\n`);
    }

    // Send done event.
    res.write(`data: ${JSON.stringify({done: true})}\n\n`);
    res.end();
  } catch (error) {
    logger.error("Alan agent error", {error});
    res.write(`data: ${JSON.stringify({error: {code: "agent_error", message: String(error)}})}\n\n`);
    res.end();
  }
});

/**
 * Non-streaming Alan endpoint for simpler integrations.
 * Returns complete response as JSON.
 */
export const alanSync = onRequest({cors: true, maxInstances: 10}, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send({error: "Method not allowed. Use POST."});
    return;
  }

  const parseResult = AlanRequestSchema.safeParse(req.body);
  if (!parseResult.success) {
    res.status(400).send({
      error: "Invalid request",
      details: parseResult.error.message,
    });
    return;
  }

  const request: AlanRequest = parseResult.data;
  const apiKey = process.env.GOOGLE_GENAI_API_KEY;

  if (!apiKey) {
    res.status(500).send({error: "API key not configured"});
    return;
  }

  try {
    const contents = request.messages.map((m) => ({
      role: m.role === "assistant" ? "model" : "user",
      parts: [{text: m.content}],
    }));

    // Build system instruction with session model context.
    let systemPrompt = ALAN_SYSTEM_PROMPT;
    if (request.session_model) {
      systemPrompt += `\n\n## Current Session Model\n\`\`\`json\n${JSON.stringify(request.session_model, null, 2)}\n\`\`\``;
    } else {
      systemPrompt += `\n\n## Current Session Model\nNo session model provided. This is the first turn. Initialize a new session model with session_id: "${request.notebook_context.document_id}", turn_count: 1, goal: null, concepts: {}, signals with medium engagement/none frustration/normal pace, and empty facts array.`;
    }

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`;

    const geminiResponse = await fetch(geminiUrl, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({
        systemInstruction: {parts: [{text: systemPrompt}]},
        contents,
        generationConfig: {
          temperature: 0.7,
          topP: 0.95,
          maxOutputTokens: 8192,
        },
      }),
    });

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      res.status(500).send({error: "Gemini API failed", details: errorText});
      return;
    }

    const data = await geminiResponse.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!text) {
      res.status(500).send({error: "No response from Gemini"});
      return;
    }

    try {
      const alanOutput = JSON.parse(text);
      const validated = AlanOutputSchema.safeParse(alanOutput);

      if (validated.success) {
        res.status(200).send({
          success: true,
          output: validated.data,
        });
      } else {
        res.status(200).send({
          success: true,
          output: alanOutput,
          validation_warning: validated.error.message,
        });
      }
    } catch {
      res.status(200).send({
        success: true,
        raw_text: text,
      });
    }
  } catch (error) {
    logger.error("Alan sync error", {error});
    res.status(500).send({error: "Agent error", message: String(error)});
  }
});
