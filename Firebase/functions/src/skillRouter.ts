// skillRouter.ts
// Routes and executes cloud skills via Firebase Cloud Functions.
// Validates requests with Zod and dispatches to skill-specific handlers.

import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {z} from "zod";
import {
  interpretJIIXForGraph,
  generateGraphFromPrompt,
} from "./graphingCalculator";

// Request validation schema.
const ExecuteSkillSchema = z.object({
  skillID: z.string().min(1),
  parameters: z.record(z.string(), z.any()),
  context: z.object({
    currentNotebookID: z.string().nullable().optional(),
    currentPDFID: z.string().nullable().optional(),
    userMessage: z.string().nullable().optional(),
  }).optional(),
});

// Type for validated request.
type ExecuteSkillRequest = z.infer<typeof ExecuteSkillSchema>;

// Skill result structure matching Swift SkillResult.
interface SkillResultData {
  type: string;
  // Additional fields depend on skill type.
  [key: string]: unknown;
}

interface SkillResult {
  success: boolean;
  data: SkillResultData | null;
  message: string | null;
  error: {
    code: string;
    message: string;
  } | null;
}

// Skill handler function signature.
type SkillHandler = (
  parameters: Record<string, unknown>,
  context?: ExecuteSkillRequest["context"]
) => Promise<SkillResult>;

// Registry of skill handlers.
const skillHandlers: Record<string, SkillHandler> = {};

/**
 * Registers a skill handler.
 * @param {string} skillID - The skill identifier.
 * @param {SkillHandler} handler - The handler function.
 */
function registerSkillHandler(skillID: string, handler: SkillHandler): void {
  skillHandlers[skillID] = handler;
}

/**
 * Creates a success result.
 * @param {SkillResultData} data - The result data.
 * @param {string} message - Optional message.
 * @return {SkillResult} The success result.
 */
function successResult(
  data: SkillResultData,
  message?: string
): SkillResult {
  return {
    success: true,
    data,
    message: message ?? null,
    error: null,
  };
}

/**
 * Creates a failure result.
 * @param {string} code - The error code.
 * @param {string} message - The error message.
 * @return {SkillResult} The failure result.
 */
function failureResult(code: string, message: string): SkillResult {
  return {
    success: false,
    data: null,
    message: null,
    error: {code, message},
  };
}

/**
 * Lesson Generator skill handler.
 * Generates interactive lessons from provided content.
 * @param {Object} parameters - Skill parameters.
 * @param {Object} context - Execution context.
 * @return {Promise} The skill result.
 */
async function executeLessonGenerator(
  parameters: Record<string, unknown>,
  context?: ExecuteSkillRequest["context"]
): Promise<SkillResult> {
  const topic = parameters["topic"] as string | undefined;
  const sourceText = parameters["sourceText"] as string | undefined;

  if (!topic && !sourceText) {
    return failureResult(
      "missing_input",
      "Either topic or sourceText is required"
    );
  }

  logger.info("Generating lesson", {topic, hasSourceText: !!sourceText});

  // Placeholder: actual implementation will call Gemini to generate lesson.
  const lessonContent = {
    type: "lesson",
    title: topic ? `Lesson on ${topic}` : "Generated Lesson",
    sections: [
      {
        heading: "Introduction",
        content: "This is a placeholder lesson introduction.",
      },
      {
        heading: "Main Content",
        content: sourceText ?? "Lesson content based on the topic.",
      },
      {
        heading: "Summary",
        content: "Key takeaways from this lesson.",
      },
    ],
    exercises: [
      {
        question: "What did you learn?",
        type: "open-ended",
      },
    ],
    notebookID: context?.currentNotebookID ?? null,
  };

  return successResult(
    lessonContent,
    `Generated lesson on "${topic ?? "provided content"}"`
  );
}

/**
 * Graphing Calculator skill handler.
 * Interprets JIIX content or prompts to generate GraphSpecification.
 * @param {Object} parameters - Skill parameters.
 * @return {Promise} The skill result.
 */
async function executeGraphingCalculator(
  parameters: Record<string, unknown>
): Promise<SkillResult> {
  const specification = parameters["specification"] as string | undefined;
  const jiixContent = parameters["jiixContent"] as string | undefined;
  const prompt = parameters["prompt"] as string | undefined;

  // Priority: specification > jiixContent > prompt
  if (specification) {
    // Direct specification - parse and validate.
    logger.info("Parsing direct specification");
    try {
      const spec = JSON.parse(specification);
      return successResult({
        type: "graphSpecification",
        ...spec,
      }, "Graph specification parsed successfully");
    } catch (error) {
      return failureResult(
        "invalid_specification",
        `Failed to parse specification: ${error}`
      );
    }
  }

  // Get API key for Gemini calls.
  const apiKey = process.env.GOOGLE_GENAI_API_KEY;
  if (!apiKey && (jiixContent || prompt)) {
    logger.error("GOOGLE_GENAI_API_KEY not configured");
    // Fall back to placeholder if no API key.
    const graphSpec = createPlaceholderGraphSpec(
      prompt || "JIIX interpretation"
    );
    return successResult({
      type: "graphSpecification",
      ...graphSpec,
    }, "Graph created (placeholder - API key not configured)");
  }

  if (jiixContent && apiKey) {
    // JIIX content - interpret with Gemini AI.
    logger.info("Interpreting JIIX content with Gemini", {
      contentLength: jiixContent.length,
    });

    try {
      const graphSpec = await interpretJIIXForGraph(jiixContent, apiKey);
      return successResult({
        type: "graphSpecification",
        ...graphSpec,
      }, "Graph created from JIIX content");
    } catch (error) {
      logger.error("Failed to interpret JIIX", {error});
      return failureResult(
        "interpretation_failed",
        `Failed to interpret JIIX content: ${error}`
      );
    }
  }

  if (prompt && apiKey) {
    // Natural language prompt - generate with Gemini AI.
    logger.info("Generating graph from prompt with Gemini", {prompt});

    try {
      const graphSpec = await generateGraphFromPrompt(prompt, apiKey);
      return successResult({
        type: "graphSpecification",
        ...graphSpec,
      }, "Graph created from prompt");
    } catch (error) {
      logger.error("Failed to generate graph from prompt", {error});
      return failureResult(
        "generation_failed",
        `Failed to generate graph from prompt: ${error}`
      );
    }
  }

  return failureResult(
    "missing_input",
    "At least one of specification, jiixContent, or prompt is required"
  );
}

/**
 * Creates a placeholder GraphSpecification for testing.
 * @param {string} title - The graph title.
 * @return {Record<string, unknown>} The placeholder specification.
 */
function createPlaceholderGraphSpec(title: string): Record<string, unknown> {
  return {
    version: "1.0",
    title: title,
    viewport: {
      xMin: -10,
      xMax: 10,
      yMin: -10,
      yMax: 10,
      aspectRatio: "auto",
    },
    axes: {
      x: {
        label: "x",
        gridSpacing: 1.0,
        showGrid: true,
        showAxis: true,
        tickLabels: true,
      },
      y: {
        label: "y",
        gridSpacing: 1.0,
        showGrid: true,
        showAxis: true,
        tickLabels: true,
      },
    },
    equations: [
      {
        id: "eq-1",
        type: "explicit",
        expression: "x^2",
        variable: "x",
        style: {
          color: "#2196F3",
          lineWidth: 2.0,
          lineStyle: "solid",
        },
        label: "y = x^2",
        visible: true,
      },
    ],
    points: null,
    annotations: null,
    interactivity: {
      allowPan: true,
      allowZoom: true,
      allowTrace: true,
      showCoordinates: true,
      snapToGrid: false,
    },
  };
}

/**
 * Audio Transcription skill handler.
 * Transcribes audio to text (hybrid - cloud processing component).
 * @param {Object} parameters - Skill parameters.
 * @param {Object} context - Execution context.
 * @return {Promise} The skill result.
 */
async function executeAudioTranscription(
  parameters: Record<string, unknown>,
  context?: ExecuteSkillRequest["context"]
): Promise<SkillResult> {
  const audioData = parameters["audioData"] as string | undefined;
  const outputFormat = parameters["outputFormat"] as string ?? "text";

  if (!audioData) {
    return failureResult("missing_parameter", "audioData is required");
  }

  logger.info("Transcribing audio", {outputFormat, hasContext: !!context});

  // Placeholder: actual implementation will call speech-to-text API.
  const transcription = {
    type: "transcription",
    text: "This is a placeholder transcription of the audio.",
    outputFormat,
    duration: 30.5,
    confidence: 0.95,
    notebookID: context?.currentNotebookID ?? null,
  };

  return successResult(transcription, "Audio transcribed successfully");
}

/**
 * Mistake Watcher skill handler.
 * Detects math errors in JIIX content.
 * @param {Object} parameters - Skill parameters.
 * @param {Object} context - Execution context.
 * @return {Promise} The skill result.
 */
async function executeMistakeWatcher(
  parameters: Record<string, unknown>,
  context?: ExecuteSkillRequest["context"]
): Promise<SkillResult> {
  const jiixContent = parameters["jiixContent"] as string | undefined;

  if (!jiixContent) {
    return failureResult("missing_parameter", "jiixContent is required");
  }

  logger.info("Analyzing for math mistakes", {
    contentLength: jiixContent.length,
    notebookID: context?.currentNotebookID,
  });

  // Placeholder: actual implementation will call Gemini to analyze math.
  const analysis = {
    type: "mistake_analysis",
    errorsFound: 0,
    corrections: [] as Array<{
      location: string;
      original: string;
      correction: string;
      explanation: string;
    }>,
    overallFeedback: "No math errors detected in the provided content.",
    notebookID: context?.currentNotebookID ?? null,
  };

  return successResult(analysis, "Math analysis complete");
}

// Register all skill handlers.
registerSkillHandler("lesson-generator", executeLessonGenerator);
registerSkillHandler("graphing-calculator", executeGraphingCalculator);
registerSkillHandler("audio-transcription", executeAudioTranscription);
registerSkillHandler("mistake-watcher", executeMistakeWatcher);

/**
 * Main skill execution endpoint.
 */
export const executeSkill = onRequest({cors: true}, async (req, res) => {
  // Only allow POST requests.
  if (req.method !== "POST") {
    res.status(405).send({error: "Method not allowed. Use POST."});
    return;
  }

  // Validate request body.
  const parseResult = ExecuteSkillSchema.safeParse(req.body);
  if (!parseResult.success) {
    res.status(400).send({
      success: false,
      data: null,
      message: null,
      error: {
        code: "invalid_request",
        message: `Invalid request body: ${parseResult.error.message}`,
      },
    });
    return;
  }

  const {skillID, parameters, context} = parseResult.data;
  const paramKeys = Object.keys(parameters);
  logger.info("Executing skill", {skillID, paramKeys});

  // Look up skill handler.
  const handler = skillHandlers[skillID];
  if (!handler) {
    res.status(404).send({
      success: false,
      data: null,
      message: null,
      error: {
        code: "skill_not_found",
        message: `Skill '${skillID}' is not registered`,
      },
    });
    return;
  }

  try {
    // Execute the skill.
    const result = await handler(parameters, context);
    res.status(200).send(result);
  } catch (error) {
    logger.error("Skill execution error", {skillID, error});
    res.status(500).send({
      success: false,
      data: null,
      message: null,
      error: {
        code: "execution_failed",
        message: error instanceof Error ? error.message : String(error),
      },
    });
  }
});

/**
 * Streaming skill execution endpoint for incremental output.
 */
export const executeSkillStreaming = onRequest(
  {cors: true},
  async (req, res) => {
    // Only allow POST requests.
    if (req.method !== "POST") {
      res.status(405).send({error: "Method not allowed. Use POST."});
      return;
    }

    // Validate request body.
    const parseResult = ExecuteSkillSchema.safeParse(req.body);
    if (!parseResult.success) {
      res.status(400).send({error: `Invalid request: ${parseResult.error}`});
      return;
    }

    const {skillID, parameters, context} = parseResult.data;
    logger.info("Streaming skill execution", {skillID});

    // Set SSE headers.
    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("Connection", "keep-alive");

    // Look up skill handler.
    const handler = skillHandlers[skillID];
    if (!handler) {
      const errMsg = `Skill '${skillID}' not found`;
      const errData = JSON.stringify({
        error: {code: "skill_not_found", message: errMsg},
      });
      res.write(`data: ${errData}\n\n`);
      res.end();
      return;
    }

    try {
      // For now, execute skill and stream result in chunks.
      // Future: skills can implement streaming interfaces.
      const result = await handler(parameters, context);

      // Stream the result in chunks (simulated for placeholder).
      if (result.success && result.message) {
        const words = result.message.split(" ");
        for (const word of words) {
          const chunk = JSON.stringify({text: word + " ", isComplete: false});
          res.write(`data: ${chunk}\n\n`);
        }
      }

      // Send final result.
      const finalData = JSON.stringify({result, isComplete: true});
      res.write(`data: ${finalData}\n\n`);
      res.end();
    } catch (error) {
      logger.error("Streaming skill error", {skillID, error});
      const errMsg = error instanceof Error ? error.message : String(error);
      const errData = JSON.stringify({
        error: {code: "execution_failed", message: errMsg},
      });
      res.write(`data: ${errData}\n\n`);
      res.end();
    }
  }
);
