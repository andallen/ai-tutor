import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {z} from "zod";
import {GoogleAuth} from "google-auth-library";

// Validation schema for the request
const GenerateEmbeddingsSchema = z.object({
  texts: z.array(z.string().min(1)).min(1).max(100),
  taskType: z.enum([
    "RETRIEVAL_DOCUMENT",
    "RETRIEVAL_QUERY",
    "SEMANTIC_SIMILARITY",
    "CLASSIFICATION",
    "CLUSTERING",
    "QUESTION_ANSWERING",
    "FACT_VERIFICATION",
  ]).optional().default("RETRIEVAL_DOCUMENT"),
});

// Initialize Google Auth for getting access tokens
const auth = new GoogleAuth({
  scopes: ["https://www.googleapis.com/auth/cloud-platform"],
});

/**
 * Cloud Function to generate embeddings for text using Vertex AI REST API.
 *
 * Uses text-embedding-005 model (768 dimensions).
 * Successor to deprecated text-embedding-004.
 *
 * @param texts - Array of strings to generate embeddings for (max 100)
 * @param taskType - Type of task for optimized embeddings:
 *   - RETRIEVAL_DOCUMENT: For indexing documents (default)
 *   - RETRIEVAL_QUERY: For search queries
 *   - SEMANTIC_SIMILARITY: For comparing text similarity
 *   - CLASSIFICATION: For text classification
 *   - CLUSTERING: For clustering texts
 *
 * @returns Object containing array of embeddings (768-dim vectors)
 */
export const generateEmbeddings = onCall(
  {
    cors: true,
    maxInstances: 10,
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async (request) => {
    // Validate request data
    const parseResult = GenerateEmbeddingsSchema.safeParse(request.data);
    if (!parseResult.success) {
      logger.error("Invalid request data", {errors: parseResult.error.issues});
      throw new HttpsError(
        "invalid-argument",
        "Invalid request data",
        parseResult.error.issues
      );
    }

    const {texts, taskType} = parseResult.data;
    logger.info("Generating embeddings", {
      textCount: texts.length,
      taskType,
      totalChars: texts.reduce((sum, t) => sum + t.length, 0),
    });

    // Get project ID from environment
    const project = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
    if (!project) {
      logger.error("GCP project not configured");
      throw new HttpsError("internal", "GCP project not configured");
    }

    const location = "us-central1";
    const model = "text-embedding-005";

    try {
      // Get access token for authentication
      const client = await auth.getClient();
      const accessToken = await client.getAccessToken();

      if (!accessToken.token) {
        throw new Error("Failed to get access token");
      }

      // Vertex AI text embeddings endpoint
      const endpoint =
        `https://${location}-aiplatform.googleapis.com/v1/` +
        `projects/${project}/locations/${location}/` +
        `publishers/google/models/${model}:predict`;

      // Process texts in batches of 5 (API limit per request)
      const batchSize = 5;
      const allEmbeddings: number[][] = [];

      for (let i = 0; i < texts.length; i += batchSize) {
        const batch = texts.slice(i, i + batchSize);

        // Build request body for the batch
        const requestBody = {
          instances: batch.map((text) => ({
            content: text,
            task_type: taskType,
          })),
          parameters: {
            outputDimensionality: 768,
          },
        };

        const response = await fetch(endpoint, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken.token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(requestBody),
        });

        if (!response.ok) {
          const errorText = await response.text();
          logger.error("Vertex AI API error", {
            status: response.status,
            error: errorText,
            batch: i / batchSize,
          });
          throw new Error(
            `Vertex AI API error: ${response.status} - ${errorText}`
          );
        }

        const data = await response.json();

        // Extract embeddings from response
        if (!data.predictions || !Array.isArray(data.predictions)) {
          throw new Error("Invalid response format from Vertex AI");
        }

        for (const prediction of data.predictions) {
          if (!prediction.embeddings?.values) {
            throw new Error("No embedding values in prediction");
          }
          allEmbeddings.push(prediction.embeddings.values);
        }

        // Small delay between batches to avoid rate limiting
        if (i + batchSize < texts.length) {
          await new Promise((resolve) => setTimeout(resolve, 100));
        }
      }

      logger.info("Embeddings generated successfully", {
        count: allEmbeddings.length,
        dimensions: allEmbeddings[0]?.length || 0,
      });

      return {
        embeddings: allEmbeddings,
        model: model,
        dimensions: allEmbeddings[0]?.length || 768,
      };
    } catch (error) {
      logger.error("Error generating embeddings", {error});

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        "Failed to generate embeddings",
        error instanceof Error ? error.message : String(error)
      );
    }
  }
);
