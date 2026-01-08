import {GoogleGenAI} from "@google/genai";
import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {z} from "zod";

// Zod schema for request validation (matches existing patterns)
const UploadFileSchema = z.object({
  base64Data: z.string().min(1, "base64Data is required"),
  mimeType: z.string().min(1, "mimeType is required"),
  displayName: z.string().min(1, "displayName is required"),
});

// Supported MIME types (matches Swift AttachmentMimeType)
const SUPPORTED_MIME_TYPES = [
  "image/png",
  "image/jpeg",
  "image/webp",
  "image/heic",
  "image/heif",
  "image/gif",
  "application/pdf",
  "text/plain",
];

// Size limits in bytes
const SIZE_LIMITS: Record<string, number> = {
  "image/png": 20 * 1024 * 1024, // 20MB
  "image/jpeg": 20 * 1024 * 1024,
  "image/webp": 20 * 1024 * 1024,
  "image/heic": 20 * 1024 * 1024,
  "image/heif": 20 * 1024 * 1024,
  "image/gif": 20 * 1024 * 1024,
  "application/pdf": 50 * 1024 * 1024, // 50MB
  "text/plain": 1 * 1024 * 1024, // 1MB
};

// Max polling attempts (2s intervals, ~60s total)
const MAX_POLL_ATTEMPTS = 30;
const POLL_INTERVAL_MS = 2000;

// Upload file to Gemini Files API.
// Receives base64-encoded file data, uploads to Gemini, polls until ready,
// returns file URI for use in chat messages.
export const uploadFile = onRequest(
  {
    cors: true,
    timeoutSeconds: 120, // Allow time for large file processing
    memory: "512MiB", // Extra memory for base64 decoding
  },
  async (req, res) => {
    // Only accept POST
    if (req.method !== "POST") {
      res.status(405).send({error: "Method not allowed"});
      return;
    }

    // Validate request body
    const parseResult = UploadFileSchema.safeParse(req.body);
    if (!parseResult.success) {
      logger.warn("Invalid uploadFile request", {
        issues: parseResult.error.issues,
      });
      res.status(400).send({
        error: "Invalid request body",
        details: parseResult.error.issues,
      });
      return;
    }

    const {base64Data, mimeType, displayName} = parseResult.data;

    // Validate MIME type
    if (!SUPPORTED_MIME_TYPES.includes(mimeType)) {
      logger.warn("Unsupported MIME type", {mimeType});
      res.status(400).send({
        error: "Unsupported file type",
        errorCode: "UNSUPPORTED_FILE_TYPE",
        mimeType,
        supportedTypes: SUPPORTED_MIME_TYPES,
      });
      return;
    }

    // Decode and validate size
    let buffer: Buffer;
    try {
      buffer = Buffer.from(base64Data, "base64");
    } catch (error) {
      logger.error("Failed to decode base64", {error});
      res.status(400).send({
        error: "Invalid base64 data",
        errorCode: "INVALID_BASE64",
      });
      return;
    }

    const sizeLimit = SIZE_LIMITS[mimeType] || 20 * 1024 * 1024;
    if (buffer.length > sizeLimit) {
      logger.warn("File too large", {size: buffer.length, limit: sizeLimit});
      res.status(400).send({
        error: "File too large",
        errorCode: "FILE_TOO_LARGE",
        sizeBytes: buffer.length,
        limitBytes: sizeLimit,
      });
      return;
    }

    if (buffer.length === 0) {
      res.status(400).send({
        error: "Empty file",
        errorCode: "EMPTY_FILE",
      });
      return;
    }

    // Initialize SDK
    const apiKey = process.env.GOOGLE_GENAI_API_KEY;
    if (!apiKey) {
      logger.error("GOOGLE_GENAI_API_KEY not configured");
      res.status(500).send({
        error: "Server configuration error",
        errorCode: "CONFIG_ERROR",
      });
      return;
    }

    const ai = new GoogleGenAI({apiKey});

    try {
      logger.info("Uploading file to Gemini Files API", {
        displayName,
        mimeType,
        sizeBytes: buffer.length,
      });

      // Create Blob from buffer (convert to Uint8Array for type compatibility)
      const uint8Array = new Uint8Array(buffer);
      const blob = new Blob([uint8Array], {type: mimeType});

      // Upload to Files API
      const file = await ai.files.upload({
        file: blob,
        config: {displayName, mimeType},
      });

      if (!file.name) {
        throw new Error("Upload returned no file name");
      }

      // Poll until processing complete
      let uploaded = await ai.files.get({name: file.name});
      let attempts = 0;

      while (uploaded.state === "PROCESSING" && attempts < MAX_POLL_ATTEMPTS) {
        logger.info("File processing...", {
          name: file.name,
          attempt: attempts + 1,
        });
        await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS));
        uploaded = await ai.files.get({name: file.name});
        attempts++;
      }

      if (uploaded.state === "PROCESSING") {
        logger.error("File processing timed out", {name: file.name});
        res.status(504).send({
          error: "File processing timed out",
          errorCode: "PROCESSING_TIMEOUT",
        });
        return;
      }

      if (uploaded.state === "FAILED") {
        logger.error("File processing failed", {name: file.name});
        res.status(500).send({
          error: "File processing failed",
          errorCode: "PROCESSING_FAILED",
        });
        return;
      }

      logger.info("File upload successful", {
        name: uploaded.name,
        uri: uploaded.uri,
        state: uploaded.state,
      });

      // Return file reference (matches Swift UploadedFileReference)
      res.status(200).send({
        fileUri: uploaded.uri,
        mimeType: uploaded.mimeType,
        name: uploaded.name,
        expiresAt: uploaded.expirationTime || null,
      });
    } catch (error) {
      logger.error("Upload failed", {error, displayName, mimeType});
      res.status(500).send({
        error: "File upload failed",
        errorCode: "UPLOAD_FAILED",
        details: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }
);
