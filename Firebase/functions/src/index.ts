import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {z} from "zod";
import {geminiGenerateUrl, geminiStreamUrl} from "./config";

// Export embeddings function for RAG indexing
export {generateEmbeddings} from "./embeddings";

// Export lesson generation functions
export {generateLesson, generateLessonSync} from "./lessonGeneration";

// Export answer comparison function
export {compareAnswer} from "./answerComparison";

// Export lesson planning function (Stage 1 of two-stage pipeline)
export {generateLessonPlan} from "./lessonPlanning";

// Set maximum instances for cost control
setGlobalOptions({maxInstances: 10});

// Validation schemas
const MessageSchema = z.object({
  role: z.enum(["user", "assistant"]),
  content: z.string().min(1),
});

const SendMessageSchema = z.object({
  messages: z.array(MessageSchema).min(1),
});

// Simple test endpoint to verify deployment works
export const testHttp = onRequest({cors: true}, async (req, res) => {
  logger.info("Test endpoint called");
  res.status(200).send({
    message: "Firebase function is working!",
    timestamp: new Date().toISOString(),
  });
});

// Main AI chat endpoint - supports multi-turn conversations
export const sendMessage = onRequest({cors: true}, async (req, res) => {
  // Only allow POST requests
  if (req.method !== "POST") {
    res.status(405).send({error: "Method not allowed. Use POST."});
    return;
  }

  // Validate request body
  const parseResult = SendMessageSchema.safeParse(req.body);
  if (!parseResult.success) {
    res.status(400).send({
      error: "Invalid request body",
      details: parseResult.error.issues,
    });
    return;
  }

  const {messages} = parseResult.data;
  logger.info("Received chat request", {messageCount: messages.length});

  // Get API key from environment
  const apiKey = process.env.GOOGLE_GENAI_API_KEY;
  if (!apiKey) {
    logger.error("GOOGLE_GENAI_API_KEY not configured");
    res.status(500).send({error: "API key not configured"});
    return;
  }

  // Transform messages to Gemini format
  // App uses "assistant", Gemini uses "model"
  const contents = messages.map((msg) => ({
    role: msg.role === "assistant" ? "model" : "user",
    parts: [{text: msg.content}],
  }));

  try {
    const response = await fetch(
      geminiGenerateUrl(apiKey),
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({contents}),
      }
    );

    const data = await response.json();

    if (!response.ok) {
      logger.error("Gemini API error", {status: response.status, data});
      throw new Error(`Gemini API error: ${JSON.stringify(data)}`);
    }

    const text = data.candidates[0].content.parts[0].text;

    logger.info("Generated response", {responseLength: text.length});
    res.status(200).send({response: text});
  } catch (error) {
    logger.error("Error generating response", {error});
    res.status(500).send({
      error: "Failed to generate response",
      details: error instanceof Error ? error.message : String(error),
    });
  }
});

// Streaming AI chat endpoint - returns Server-Sent Events
export const streamMessage = onRequest({cors: true}, async (req, res) => {
  // Only allow POST requests
  if (req.method !== "POST") {
    res.status(405).send({error: "Method not allowed. Use POST."});
    return;
  }

  // Validate request body
  const parseResult = SendMessageSchema.safeParse(req.body);
  if (!parseResult.success) {
    res.status(400).send({
      error: "Invalid request body",
      details: parseResult.error.issues,
    });
    return;
  }

  const {messages} = parseResult.data;
  const msgCount = messages.length;
  logger.info("Received streaming chat request", {messageCount: msgCount});

  // Get API key from environment
  const apiKey = process.env.GOOGLE_GENAI_API_KEY;
  if (!apiKey) {
    logger.error("GOOGLE_GENAI_API_KEY not configured");
    res.status(500).send({error: "API key not configured"});
    return;
  }

  // Transform messages to Gemini format
  const contents = messages.map((msg) => ({
    role: msg.role === "assistant" ? "model" : "user",
    parts: [{text: msg.content}],
  }));

  // Set SSE headers
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");

  try {
    const response = await fetch(
      geminiStreamUrl(apiKey),
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({contents}),
      }
    );

    if (!response.ok) {
      const errorData = await response.text();
      logger.error("Gemini API error", {status: response.status, errorData});
      res.write(`data: ${JSON.stringify({error: "Gemini API error"})}\n\n`);
      res.end();
      return;
    }

    // Stream the response chunks to the client
    const reader = response.body?.getReader();
    if (!reader) {
      res.write(`data: ${JSON.stringify({error: "No response body"})}\n\n`);
      res.end();
      return;
    }

    const decoder = new TextDecoder();
    let buffer = "";
    let streamDone = false;

    while (!streamDone) {
      const {done, value} = await reader.read();
      if (done) {
        streamDone = true;
        continue;
      }

      buffer += decoder.decode(value, {stream: true});

      // Parse SSE events from buffer
      const lines = buffer.split("\n");
      buffer = lines.pop() || ""; // Keep incomplete line in buffer

      for (const line of lines) {
        if (line.startsWith("data: ")) {
          const jsonStr = line.slice(6);
          if (jsonStr.trim()) {
            try {
              const data = JSON.parse(jsonStr);
              // Extract text from Gemini response
              const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
              if (text) {
                res.write(`data: ${JSON.stringify({text})}\n\n`);
              }
            } catch {
              // Skip malformed JSON chunks
            }
          }
        }
      }
    }

    // Send done signal
    res.write(`data: ${JSON.stringify({done: true})}\n\n`);
    res.end();
    logger.info("Streaming response completed");
  } catch (error) {
    logger.error("Error in streaming response", {error});
    res.write(`data: ${JSON.stringify({
      error: "Failed to generate response",
      details: error instanceof Error ? error.message : String(error),
    })}\n\n`);
    res.end();
  }
});
