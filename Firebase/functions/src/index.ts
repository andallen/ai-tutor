import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {z} from "zod";

// Export embeddings function for RAG indexing
export {generateEmbeddings} from "./embeddings";

// Export file upload function for multimodal chat
export {uploadFile} from "./files";

// Set maximum instances for cost control
setGlobalOptions({maxInstances: 10});

// Token budget constants (must match Swift TokenBudgetConstants)
const TOKEN_CONSTANTS = {
  geminiMaxTokens: 1_048_576,
  systemReserveTokens: 10_000,
  responseBufferTokens: 8_192,
  maxInputTokens: 1_030_384,
  charsPerToken: 4.0,
};

// Validation schemas

// Legacy message schema (text-only)
const MessageSchema = z.object({
  role: z.enum(["user", "assistant"]),
  content: z.string().min(1),
});

// Multimodal part schemas
const TextPartSchema = z.object({
  text: z.string().min(1),
});

const FileDataPartSchema = z.object({
  fileData: z.object({
    fileUri: z.string().min(1),
    mimeType: z.string().min(1),
  }),
});

const MessagePartSchema = z.union([TextPartSchema, FileDataPartSchema]);

// Multimodal message schema (new format with parts array)
const MultimodalMessageSchema = z.object({
  role: z.enum(["user", "assistant"]),
  parts: z.array(MessagePartSchema).min(1),
});

// Union schema accepts both legacy and multimodal formats
const FlexibleMessageSchema = z.union([
  MessageSchema, // Legacy: {role, content}
  MultimodalMessageSchema, // New: {role, parts}
]);

// Updated schema that accepts both formats
const SendMessageSchema = z.object({
  messages: z.array(FlexibleMessageSchema).min(1),
});

// Input types from Swift client (camelCase)
interface TextPart {
  text: string;
}

interface FileDataPart {
  fileData: {
    fileUri: string;
    mimeType: string;
  };
}

type MessagePart = TextPart | FileDataPart;

interface LegacyMessage {
  role: "user" | "assistant";
  content: string;
}

interface MultimodalMessage {
  role: "user" | "assistant";
  parts: MessagePart[];
}

type FlexibleMessage = LegacyMessage | MultimodalMessage;

// Gemini API format (snake_case for REST API)
interface GeminiTextPart {
  text: string;
}

interface GeminiFileDataPart {
  file_data: {
    file_uri: string;
    mime_type: string;
  };
}

type GeminiPart = GeminiTextPart | GeminiFileDataPart;

interface GeminiContent {
  role: string;
  parts: GeminiPart[];
}

// Token metadata types for responses
interface TokenMetadata {
  promptTokenCount: number;
  candidatesTokenCount: number;
  totalTokenCount: number;
}

interface StreamTokenMetadata extends TokenMetadata {
  historyTruncated: boolean;
  messagesIncluded: number;
}

/**
 * Counts tokens using Gemini's countTokens API.
 * Returns null if counting fails (allows graceful degradation).
 * @param {Array} contents - Array of content objects with role and parts.
 * @param {string} apiKey - The Google GenAI API key.
 * @return {Promise<number | null>} Token count or null on failure.
 */
async function countTokens(
  contents: Array<{role: string; parts: Array<{text: string}>}>,
  apiKey: string
): Promise<number | null> {
  try {
    const modelUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/" +
      `gemini-3.0-flash-preview:countTokens?key=${apiKey}`;
    const response = await fetch(
      modelUrl,
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({contents}),
      }
    );

    if (!response.ok) {
      logger.warn("Token counting failed", {status: response.status});
      return null;
    }

    const data = await response.json();
    return data.totalTokens || null;
  } catch (error) {
    logger.warn("Token counting error", {error});
    return null;
  }
}

/**
 * Type guard for legacy message format detection.
 * @param {FlexibleMessage} msg - The message to check.
 * @return {boolean} True if message is in legacy format.
 */
function isLegacyMessage(msg: FlexibleMessage): msg is LegacyMessage {
  return "content" in msg;
}

/**
 * Type guard for text part detection.
 * @param {MessagePart} part - The message part to check.
 * @return {boolean} True if part is a text part.
 */
function isTextPart(part: MessagePart): part is TextPart {
  return "text" in part;
}

/**
 * Transform messages from app format to Gemini API format.
 * - Converts "assistant" role to "model"
 * - Converts camelCase fileData to snake_case file_data
 * - Handles both legacy {role, content} and multimodal {role, parts} formats
 * @param {FlexibleMessage[]} messages - Messages to transform.
 * @return {GeminiContent[]} Transformed messages for Gemini API.
 */
function toGeminiContents(messages: FlexibleMessage[]): GeminiContent[] {
  return messages.map((msg) => {
    const role = msg.role === "assistant" ? "model" : "user";

    if (isLegacyMessage(msg)) {
      // Legacy format: {role, content} -> {role, parts: [{text}]}
      return {
        role,
        parts: [{text: msg.content}],
      };
    }

    // Multimodal format: transform parts to Gemini snake_case format
    const parts: GeminiPart[] = msg.parts.map((part) => {
      if (isTextPart(part)) {
        return {text: part.text};
      }
      // FileDataPart -> Gemini snake_case format
      return {
        file_data: {
          file_uri: part.fileData.fileUri,
          mime_type: part.fileData.mimeType,
        },
      };
    });

    return {role, parts};
  });
}

/**
 * Extract text-only contents for token counting.
 * File parts don't contribute to text token count (billed separately).
 * @param {GeminiContent[]} contents - Contents to extract text from.
 * @return {Array} Text-only contents for token counting.
 */
function toTextOnlyContents(
  contents: GeminiContent[]
): Array<{role: string; parts: Array<{text: string}>}> {
  return contents
    .map((content) => ({
      role: content.role,
      parts: content.parts
        .filter((part): part is GeminiTextPart => "text" in part)
        .map((part) => ({text: part.text})),
    }))
    .filter((content) => content.parts.length > 0);
}

/**
 * Estimate tokens for a GeminiContent message.
 * Text uses character heuristic, file parts use fixed estimate.
 * @param {GeminiContent} content - The content to estimate tokens for.
 * @return {number} Estimated token count.
 */
function estimateTokensFromContent(content: GeminiContent): number {
  let tokens = 0;
  for (const part of content.parts) {
    if ("text" in part) {
      const textLen = part.text.length;
      tokens += Math.ceil(textLen / TOKEN_CONSTANTS.charsPerToken);
    }
    // File parts: estimate ~258 tokens for images, ~750/page for PDFs
    // Use conservative fixed estimate since actual count varies by content
    if ("file_data" in part) {
      tokens += 500;
    }
  }
  return tokens;
}

/**
 * Truncates GeminiContent messages to fit within token limit.
 * Always keeps the newest message, removes oldest first.
 * @param {GeminiContent[]} contents - Contents to truncate.
 * @param {number} maxTokens - Maximum tokens allowed.
 * @return {Object} Truncated contents and truncation status.
 */
function truncateGeminiContents(
  contents: GeminiContent[],
  maxTokens: number
): {contents: GeminiContent[]; truncated: boolean} {
  if (contents.length === 0) {
    return {contents: [], truncated: false};
  }

  const newest = contents[contents.length - 1];
  const older = contents.slice(0, -1).reverse();

  const result = [newest];
  let currentTokens = estimateTokensFromContent(newest);

  for (const msg of older) {
    const msgTokens = estimateTokensFromContent(msg);
    if (currentTokens + msgTokens > maxTokens) {
      break;
    }
    result.unshift(msg);
    currentTokens += msgTokens;
  }

  return {
    contents: result,
    truncated: result.length < contents.length,
  };
}

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

  // Transform messages to Gemini format (handles both legacy and multimodal)
  let contents = toGeminiContents(messages as FlexibleMessage[]);

  // Extract text-only contents for token counting
  // (file parts billed separately)
  const textOnlyContents = toTextOnlyContents(contents);

  // Count tokens and validate
  let historyTruncated = false;
  const inputTokenCount = await countTokens(textOnlyContents, apiKey);

  // Check if the newest message alone exceeds the absolute maximum
  if (contents.length > 0) {
    const lastContent = contents[contents.length - 1];
    const newestTextOnly = toTextOnlyContents([lastContent]);
    const newestTokenCount = newestTextOnly.length > 0 ?
      await countTokens(newestTextOnly, apiKey) : 0;

    const exceedsMax =
      newestTokenCount && newestTokenCount > TOKEN_CONSTANTS.geminiMaxTokens;
    if (exceedsMax) {
      logger.warn("Single message exceeds token limit", {
        tokenCount: newestTokenCount,
        maxTokens: TOKEN_CONSTANTS.geminiMaxTokens,
      });
      const errorDetails =
        `This message contains ${newestTokenCount} tokens, ` +
        `but the maximum is ${TOKEN_CONSTANTS.geminiMaxTokens} tokens. ` +
        "Please reduce the amount of context or split into multiple messages.";
      res.status(400).send({
        error: "Message is too large",
        errorCode: "MESSAGE_TOO_LARGE",
        details: errorDetails,
        tokenCount: newestTokenCount,
        maxTokens: TOKEN_CONSTANTS.geminiMaxTokens,
      });
      return;
    }
  }

  // Truncate conversation history if needed
  if (inputTokenCount && inputTokenCount > TOKEN_CONSTANTS.maxInputTokens) {
    logger.info("Truncating messages", {
      originalTokens: inputTokenCount,
      maxTokens: TOKEN_CONSTANTS.maxInputTokens,
    });
    const truncateResult = truncateGeminiContents(
      contents,
      TOKEN_CONSTANTS.maxInputTokens
    );
    contents = truncateResult.contents;
    historyTruncated = truncateResult.truncated;
  }

  const messagesIncluded = contents.length;

  try {
    const generateUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/" +
      `gemini-3.0-flash-preview:generateContent?key=${apiKey}`;
    const response = await fetch(
      generateUrl,
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({contents}),
      }
    );

    const data = await response.json();

    if (!response.ok) {
      logger.error("Gemini API error", {status: response.status, data});

      // Check for token limit error
      if (response.status === 400 && data.error?.message?.includes("token")) {
        res.status(400).send({
          error: "Request exceeds token limit",
          errorCode: "TOKEN_LIMIT_EXCEEDED",
          tokenCount: inputTokenCount,
          maxTokens: TOKEN_CONSTANTS.geminiMaxTokens,
        });
        return;
      }

      throw new Error(`Gemini API error: ${JSON.stringify(data)}`);
    }

    const text = data.candidates[0].content.parts[0].text;

    // Extract token usage from Gemini response
    const usageMetadata = data.usageMetadata;
    let tokenMetadata: TokenMetadata | undefined;

    if (usageMetadata) {
      tokenMetadata = {
        promptTokenCount: usageMetadata.promptTokenCount || 0,
        candidatesTokenCount: usageMetadata.candidatesTokenCount || 0,
        totalTokenCount: usageMetadata.totalTokenCount || 0,
      };
    }

    logger.info("Generated response", {
      responseLength: text.length,
      tokenMetadata,
      historyTruncated,
      messagesIncluded,
    });

    // Build response with token metadata
    const responseBody: {
      response: string;
      tokenMetadata?: TokenMetadata;
      historyTruncated: boolean;
      messagesIncluded: number;
    } = {
      response: text,
      historyTruncated,
      messagesIncluded,
    };

    if (tokenMetadata) {
      responseBody.tokenMetadata = tokenMetadata;
    }

    res.status(200).send(responseBody);
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
  logger.info("Received streaming chat request", {
    messageCount: messages.length,
  });

  // Get API key from environment
  const apiKey = process.env.GOOGLE_GENAI_API_KEY;
  if (!apiKey) {
    logger.error("GOOGLE_GENAI_API_KEY not configured");
    res.status(500).send({error: "API key not configured"});
    return;
  }

  // Transform messages to Gemini format (handles both legacy and multimodal)
  let contents = toGeminiContents(messages as FlexibleMessage[]);

  // Extract text-only contents for token counting
  // (file parts billed separately)
  const textOnlyContents = toTextOnlyContents(contents);

  // Count tokens and validate
  let historyTruncated = false;
  const inputTokenCount = await countTokens(textOnlyContents, apiKey);

  // Check if the newest message alone exceeds the absolute maximum
  if (contents.length > 0) {
    const lastContent = contents[contents.length - 1];
    const newestTextOnly = toTextOnlyContents([lastContent]);
    const newestTokenCount = newestTextOnly.length > 0 ?
      await countTokens(newestTextOnly, apiKey) : 0;

    const exceedsMax =
      newestTokenCount && newestTokenCount > TOKEN_CONSTANTS.geminiMaxTokens;
    if (exceedsMax) {
      logger.warn("Single message exceeds token limit (streaming)", {
        tokenCount: newestTokenCount,
        maxTokens: TOKEN_CONSTANTS.geminiMaxTokens,
      });
      const errorDetails =
        `This message contains ${newestTokenCount} tokens, ` +
        `but the maximum is ${TOKEN_CONSTANTS.geminiMaxTokens} tokens. ` +
        "Please reduce the amount of context or split into multiple messages.";
      res.status(400).send({
        error: "Message is too large",
        errorCode: "MESSAGE_TOO_LARGE",
        details: errorDetails,
        tokenCount: newestTokenCount,
        maxTokens: TOKEN_CONSTANTS.geminiMaxTokens,
      });
      return;
    }
  }

  // Truncate conversation history if needed
  if (inputTokenCount && inputTokenCount > TOKEN_CONSTANTS.maxInputTokens) {
    logger.info("Truncating messages for streaming", {
      originalTokens: inputTokenCount,
      maxTokens: TOKEN_CONSTANTS.maxInputTokens,
    });
    const truncateResult = truncateGeminiContents(
      contents,
      TOKEN_CONSTANTS.maxInputTokens
    );
    contents = truncateResult.contents;
    historyTruncated = truncateResult.truncated;
  }

  const messagesIncluded = contents.length;

  // Set SSE headers
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");

  try {
    const streamUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/" +
      `gemini-3.0-flash-preview:streamGenerateContent?alt=sse&key=${apiKey}`;
    const response = await fetch(
      streamUrl,
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
    let lastUsageMetadata: {
      promptTokenCount?: number;
      candidatesTokenCount?: number;
      totalTokenCount?: number;
    } | null = null;

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

              // Capture usage metadata from the last chunk
              if (data.usageMetadata) {
                lastUsageMetadata = data.usageMetadata;
              }

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

    // Build token metadata for the final chunk
    const streamTokenMetadata: StreamTokenMetadata = {
      promptTokenCount: lastUsageMetadata?.promptTokenCount || 0,
      candidatesTokenCount: lastUsageMetadata?.candidatesTokenCount || 0,
      totalTokenCount: lastUsageMetadata?.totalTokenCount || 0,
      historyTruncated,
      messagesIncluded,
    };

    // Send done signal with token metadata
    res.write(`data: ${JSON.stringify({
      done: true,
      tokenMetadata: streamTokenMetadata,
    })}\n\n`);
    res.end();

    logger.info("Streaming response completed", {
      tokenMetadata: streamTokenMetadata,
    });
  } catch (error) {
    logger.error("Error in streaming response", {error});
    res.write(`data: ${JSON.stringify({
      error: "Failed to generate response",
      details: error instanceof Error ? error.message : String(error),
      done: true,
    })}\n\n`);
    res.end();
  }
});
