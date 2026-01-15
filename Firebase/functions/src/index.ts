import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

// Export embeddings function for RAG indexing
export {generateEmbeddings} from "./embeddings";

// Export file upload function for multimodal chat
export {uploadFile} from "./files";

// Export Alan tutoring agent endpoints
export {alan, alanSync} from "./alan/alanAgent";

// Export subagent router endpoints
export {executeSubagent, executeSubagentBatch} from "./subagents/subagentRouter";

// Set maximum instances for cost control
setGlobalOptions({maxInstances: 10});

// Simple test endpoint to verify deployment works
export const testHttp = onRequest({cors: true}, async (req, res) => {
  logger.info("Test endpoint called");
  res.status(200).send({
    message: "Firebase function is working!",
    timestamp: new Date().toISOString(),
  });
});
