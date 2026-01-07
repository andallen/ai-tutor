import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {z} from "zod";

// Export embeddings function for RAG indexing
export {generateEmbeddings} from "./embeddings";

// Export skill execution functions
export {executeSkill, executeSkillStreaming} from "./skillRouter";

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
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=${apiKey}`,
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
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:streamGenerateContent?alt=sse&key=${apiKey}`,
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

// Tool/function declaration schema for Gemini function calling.
const ToolPropertySchema = z.object({
  type: z.string(),
  description: z.string().optional(),
  enum: z.array(z.string()).optional(),
});

const ToolParametersSchema = z.object({
  type: z.literal("object"),
  properties: z.record(z.string(), ToolPropertySchema),
  required: z.array(z.string()).optional(),
});

const ToolDeclarationSchema = z.object({
  name: z.string().min(1),
  description: z.string(),
  parameters: ToolParametersSchema,
});

const ToolConfigSchema = z.object({
  functionCallingConfig: z.object({
    mode: z.enum(["AUTO", "ANY", "NONE"]).default("AUTO"),
    allowedFunctionNames: z.array(z.string()).optional(),
  }).optional(),
}).optional();

const SendMessageWithToolsSchema = z.object({
  messages: z.array(MessageSchema).min(1),
  tools: z.array(ToolDeclarationSchema).optional(),
  toolConfig: ToolConfigSchema,
});

// AI chat endpoint with function/tool calling support.
// Enables Gemini to invoke skills via function declarations.
export const sendMessageWithTools = onRequest(
  {cors: true},
  async (req, res) => {
  // Only allow POST requests.
    if (req.method !== "POST") {
      res.status(405).send({error: "Method not allowed. Use POST."});
      return;
    }

    // Validate request body.
    const parseResult = SendMessageWithToolsSchema.safeParse(req.body);
    if (!parseResult.success) {
      res.status(400).send({
        error: "Invalid request body",
        details: parseResult.error.issues,
      });
      return;
    }

    const {messages, tools, toolConfig} = parseResult.data;
    logger.info("Received chat with tools request", {
      messageCount: messages.length,
      toolCount: tools?.length ?? 0,
    });

    // Get API key from environment.
    const apiKey = process.env.GOOGLE_GENAI_API_KEY;
    if (!apiKey) {
      logger.error("GOOGLE_GENAI_API_KEY not configured");
      res.status(500).send({error: "API key not configured"});
      return;
    }

    // Transform messages to Gemini format.
    const contents = messages.map((msg) => ({
      role: msg.role === "assistant" ? "model" : "user",
      parts: [{text: msg.content}],
    }));

  // Build request body with optional tools.
  interface GeminiRequest {
    contents: typeof contents;
    tools?: Array<{functionDeclarations: typeof tools}>;
    toolConfig?: {
      functionCallingConfig: {
        mode: string;
        allowedFunctionNames?: string[];
      };
    };
  }

  const requestBody: GeminiRequest = {contents};

  if (tools && tools.length > 0) {
    // Format tools as Gemini expects.
    requestBody.tools = [{
      functionDeclarations: tools.map((tool) => ({
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters,
      })),
    }];

    // Add tool config if provided.
    if (toolConfig?.functionCallingConfig) {
      requestBody.toolConfig = {
        functionCallingConfig: {
          mode: toolConfig.functionCallingConfig.mode ?? "AUTO",
          ...(toolConfig.functionCallingConfig.allowedFunctionNames && {
            allowedFunctionNames:
              toolConfig.functionCallingConfig.allowedFunctionNames,
          }),
        },
      };
    }
  }

  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify(requestBody),
      }
    );

    const data = await response.json();

    if (!response.ok) {
      logger.error("Gemini API error", {status: response.status, data});
      throw new Error(`Gemini API error: ${JSON.stringify(data)}`);
    }

    // Check for function call in response.
    const candidate = data.candidates?.[0];
    const content = candidate?.content;
    const parts = content?.parts;

    if (!parts || parts.length === 0) {
      logger.warn("Empty response from Gemini");
      res.status(200).send({type: "text", content: ""});
      return;
    }

    // Check if Gemini returned a function call.
    const functionCallPart = parts.find(
      (part: {functionCall?: unknown}) => part.functionCall
    );

    if (functionCallPart?.functionCall) {
      const functionCall = functionCallPart.functionCall as {
        name: string;
        args: Record<string, unknown>;
      };

      logger.info("Gemini requested function call", {
        functionName: functionCall.name,
        args: functionCall.args,
      });

      res.status(200).send({
        type: "functionCall",
        functionCall: {
          name: functionCall.name,
          args: functionCall.args,
        },
      });
      return;
    }

    // Check for text response.
    const textPart = parts.find(
      (part: {text?: string}) => typeof part.text === "string"
    );

    if (textPart?.text) {
      logger.info("Gemini returned text", {length: textPart.text.length});
      res.status(200).send({
        type: "text",
        content: textPart.text,
      });
      return;
    }

    // Fallback: return raw parts if neither function call nor text.
    logger.warn("Unexpected response format from Gemini", {parts});
    res.status(200).send({
      type: "unknown",
      parts,
    });
  } catch (error) {
    logger.error("Error in sendMessageWithTools", {error});
    res.status(500).send({
      error: "Failed to generate response",
      details: error instanceof Error ? error.message : String(error),
    });
  }
  });

// Streaming AI chat with tools - SSE with function call or text chunks.
export const streamMessageWithTools = onRequest(
  {cors: true},
  async (req, res) => {
  // Only allow POST requests.
    if (req.method !== "POST") {
      res.status(405).send({error: "Method not allowed. Use POST."});
      return;
    }

    // Validate request body.
    const parseResult = SendMessageWithToolsSchema.safeParse(req.body);
    if (!parseResult.success) {
      res.status(400).send({
        error: "Invalid request body",
        details: parseResult.error.issues,
      });
      return;
    }

    const {messages, tools, toolConfig} = parseResult.data;
    logger.info("Received streaming chat with tools", {
      messageCount: messages.length,
      toolCount: tools?.length ?? 0,
    });

    // Get API key from environment.
    const apiKey = process.env.GOOGLE_GENAI_API_KEY;
    if (!apiKey) {
      logger.error("GOOGLE_GENAI_API_KEY not configured");
      res.status(500).send({error: "API key not configured"});
      return;
    }

    // Transform messages to Gemini format.
    const contents = messages.map((msg) => ({
      role: msg.role === "assistant" ? "model" : "user",
      parts: [{text: msg.content}],
    }));

  // Build request body with optional tools.
  interface GeminiRequest {
    contents: typeof contents;
    tools?: Array<{functionDeclarations: typeof tools}>;
    toolConfig?: {
      functionCallingConfig: {
        mode: string;
        allowedFunctionNames?: string[];
      };
    };
  }

  const requestBody: GeminiRequest = {contents};

  if (tools && tools.length > 0) {
    requestBody.tools = [{
      functionDeclarations: tools.map((tool) => ({
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters,
      })),
    }];

    if (toolConfig?.functionCallingConfig) {
      requestBody.toolConfig = {
        functionCallingConfig: {
          mode: toolConfig.functionCallingConfig.mode ?? "AUTO",
          ...(toolConfig.functionCallingConfig.allowedFunctionNames && {
            allowedFunctionNames:
              toolConfig.functionCallingConfig.allowedFunctionNames,
          }),
        },
      };
    }
  }

  // Set SSE headers.
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");

  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:streamGenerateContent?alt=sse&key=${apiKey}`,
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify(requestBody),
      }
    );

    if (!response.ok) {
      const errorData = await response.text();
      logger.error("Gemini API error", {status: response.status, errorData});
      res.write(`data: ${JSON.stringify({error: "Gemini API error"})}\n\n`);
      res.end();
      return;
    }

    const reader = response.body?.getReader();
    if (!reader) {
      res.write(`data: ${JSON.stringify({error: "No response body"})}\n\n`);
      res.end();
      return;
    }

    const decoder = new TextDecoder();
    let buffer = "";
    let streamDone = false;
    let functionCallDetected = false;
    type FunctionCall = {name: string; args: Record<string, unknown>};
    let accumulatedFunctionCall: FunctionCall | null = null;

    while (!streamDone) {
      const {done, value} = await reader.read();
      if (done) {
        streamDone = true;
        continue;
      }

      buffer += decoder.decode(value, {stream: true});

      // Parse SSE events from buffer.
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";

      for (const line of lines) {
        if (line.startsWith("data: ")) {
          const jsonStr = line.slice(6);
          if (jsonStr.trim()) {
            try {
              const data = JSON.parse(jsonStr);
              const parts = data.candidates?.[0]?.content?.parts;

              if (parts) {
                for (const part of parts) {
                  // Check for function call.
                  if (part.functionCall) {
                    functionCallDetected = true;
                    accumulatedFunctionCall = {
                      name: part.functionCall.name,
                      args: part.functionCall.args,
                    };
                  }
                  // Stream text chunks.
                  if (typeof part.text === "string") {
                    res.write(`data: ${JSON.stringify({text: part.text})}\n\n`);
                  }
                }
              }
            } catch {
              // Skip malformed JSON.
            }
          }
        }
      }
    }

    // Send final response.
    if (functionCallDetected && accumulatedFunctionCall) {
      res.write(`data: ${JSON.stringify({
        type: "functionCall",
        functionCall: accumulatedFunctionCall,
        done: true,
      })}\n\n`);
    } else {
      res.write(`data: ${JSON.stringify({done: true})}\n\n`);
    }
    res.end();
    logger.info("Streaming with tools completed", {functionCallDetected});
  } catch (error) {
    logger.error("Error in streaming with tools", {error});
    res.write(`data: ${JSON.stringify({
      error: "Failed to generate response",
      details: error instanceof Error ? error.message : String(error),
    })}\n\n`);
    res.end();
  }
  });
