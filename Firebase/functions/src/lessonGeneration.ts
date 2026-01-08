import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {z} from "zod";
import {geminiGenerateUrl} from "./config";
import {generateLessonPlanCore, callGemini} from "./lessonPlanning";

// Validation schema for lesson generation request
const GenerateLessonSchema = z.object({
  prompt: z.string().min(1),
  sourceText: z.string().optional(),
  estimatedMinutes: z.number().min(5).max(60).optional().default(15),
});

/**
 * Stage 2: Transform prompt that converts a lesson plan into JSON.
 * Takes structured markdown from Stage 1 and outputs Lesson JSON format.
 * @param {string} lessonPlan - The Stage 1 lesson plan markdown.
 * @param {string} sourceType - Whether the source was "prompt" or "pdf".
 * @return {string} The prompt for JSON transformation.
 */
function buildTransformPrompt(
  lessonPlan: string,
  sourceType: string
): string {
  return `You are an expert at transforming educational content into \
interactive lesson formats.

TASK: Convert the following lesson plan into a JSON lesson format.

LESSON PLAN:
---
${lessonPlan}
---

OUTPUT FORMAT: Valid JSON only. No markdown code blocks, no explanations.

Use this exact schema:

{
  "lessonId": "uuid-string",
  "title": "Extract from LESSON PLAN header",
  "metadata": {
    "sourceType": "${sourceType}",
    "createdAt": "${new Date().toISOString()}"
  },
  "sections": [
    // For each concept in CONCEPT PROGRESSION, create:
    // 1. A content section with the Core Knowledge
    {
      "id": "uuid",
      "type": "content",
      "content": "Markdown content from Core Knowledge, including Key Insight"
    },
    // 2. A visual section (optional, for concepts that benefit from visuals)
    {
      "id": "uuid",
      "type": "visual",
      "visualType": "generated",
      "imagePrompt": "Detailed image description related to the concept"
    },
    // 3. Questions derived from Assessment Angles
    {
      "id": "uuid",
      "type": "question",
      "questionType": "multipleChoice",
      "prompt": "Question testing the concept",
      "options": ["A", "B", "C", "D"],
      "answer": "Correct option text",
      "explanation": "Why this is correct, addressing common misconception"
    },
    // At the end, a summary section
    {
      "id": "uuid",
      "type": "summary",
      "content": "Key Takeaways from SUMMARY POINTS"
    }
  ]
}

TRANSFORMATION RULES:
1. Generate unique UUIDs for lessonId and each section id
2. For each concept in CONCEPT PROGRESSION:
   - Create a content section from Core Knowledge + Key Insight
   - If the concept is visual or spatial, add a visual section
   - Create 1-2 questions from the Assessment Angles
   - Incorporate Common Misconception into question explanations
3. Question types:
   - multipleChoice: 4 options, test factual understanding
   - freeResponse: open-ended, test deeper understanding
   - math: if the concept involves calculations
4. End with a summary section using SUMMARY POINTS
5. Content uses Markdown formatting
6. Follow the concept order from SUGGESTED PROGRESSION
7. Total sections: roughly 3-4 per concept (content, visual, questions)

Generate the JSON now:`;
}

// Legacy system prompt for direct generation (kept for generateLessonSync)
const LESSON_SYSTEM_PROMPT = "You are an expert educational " +
  `content creator. Generate interactive lessons in JSON format.

IMPORTANT: Output ONLY valid JSON. ` +
  `No markdown code blocks, no explanations before or after.

Follow this exact JSON schema:

{
  "lessonId": "uuid-string",
  "title": "Lesson Title",
  "metadata": {
    "sourceType": "prompt",
    "createdAt": "ISO-8601 timestamp"
  },
  "sections": [
    {
      "id": "section-uuid",
      "type": "content",
      "content": "Markdown formatted educational content..."
    },
    {
      "id": "section-uuid",
      "type": "visual",
      "visualType": "generated",
      "imagePrompt": "Detailed image description for generation"
    },
    {
      "id": "section-uuid",
      "type": "question",
      "questionType": "multipleChoice",
      "prompt": "Question text?",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "answer": "Correct Option",
      "explanation": "Why this is correct..."
    },
    {
      "id": "section-uuid",
      "type": "question",
      "questionType": "freeResponse",
      "prompt": "Open-ended question?",
      "answer": "Model answer text",
      "explanation": "Key points to include..."
    },
    {
      "id": "section-uuid",
      "type": "question",
      "questionType": "math",
      "prompt": "Math problem?",
      "answer": "Mathematical answer"
    },
    {
      "id": "section-uuid",
      "type": "summary",
      "content": "### Key Takeaways\\n\\n- Point 1\\n- Point 2"
    }
  ]
}

Rules:
1. Generate unique UUIDs for lessonId and each section id
2. Content sections use Markdown formatting
3. Include 2-4 content sections explaining concepts
4. Include 1-2 visual sections ` +
  `with detailed imagePrompt descriptions
5. Include 2-3 questions of varying types ` +
  `(multipleChoice, freeResponse, or math)
6. End with a summary section
7. For multipleChoice questions, always provide exactly 4 options
8. Questions must have clear, specific answers
9. Use standard notation for math (subscripts as ₂, arrows as →)
10. Make content engaging and appropriate for the topic`;

// Two-stage lesson generation endpoint.
// Stage 1: Generate structured lesson plan (markdown).
// Stage 2: Transform lesson plan into interactive JSON.
export const generateLesson = onRequest({cors: true}, async (req, res) => {
  // Only allow POST requests
  if (req.method !== "POST") {
    res.status(405).send({error: "Method not allowed. Use POST."});
    return;
  }

  // Validate request body
  const parseResult = GenerateLessonSchema.safeParse(req.body);
  if (!parseResult.success) {
    res.status(400).send({
      error: "Invalid request body",
      details: parseResult.error.issues,
    });
    return;
  }

  const {prompt, sourceText} = parseResult.data;
  const sourceType = sourceText ? "pdf" : "prompt";
  logger.info("Received lesson generation request (two-stage)", {
    promptLength: prompt.length,
    hasSourceText: !!sourceText,
    sourceType,
  });

  // Get API key from environment
  const apiKey = process.env.GOOGLE_GENAI_API_KEY;
  if (!apiKey) {
    logger.error("GOOGLE_GENAI_API_KEY not configured");
    res.status(500).send({error: "API key not configured"});
    return;
  }

  // Set SSE headers
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");

  try {
    // Stage 1: Generate structured lesson plan.
    res.write(`data: ${JSON.stringify({
      stage: 1,
      status: "running",
      name: "Planning lesson content",
    })}\n\n`);

    const lessonPlan = await generateLessonPlanCore(
      apiKey,
      prompt,
      sourceText,
      (status, name) => {
        res.write(`data: ${JSON.stringify({stage: 1, status, name})}\n\n`);
      }
    );

    res.write(`data: ${JSON.stringify({
      stage: 1,
      status: "complete",
      name: "Lesson plan ready",
    })}\n\n`);

    logger.info("Stage 1 complete", {planLength: lessonPlan.length});

    // Stage 2: Transform lesson plan into interactive JSON.
    res.write(`data: ${JSON.stringify({
      stage: 2,
      status: "running",
      name: "Building interactive lesson",
    })}\n\n`);

    const transformPrompt = buildTransformPrompt(lessonPlan, sourceType);
    const lessonJson = await callGemini(apiKey, transformPrompt);

    res.write(`data: ${JSON.stringify({
      stage: 2,
      status: "complete",
      name: "Lesson ready",
    })}\n\n`);

    logger.info("Stage 2 complete", {jsonLength: lessonJson.length});

    // Send completion signal with full JSON text.
    const doneEvent = JSON.stringify({done: true, fullText: lessonJson});
    res.write(`data: ${doneEvent}\n\n`);
    res.end();

    logger.info("Two-stage lesson generation completed", {
      prompt,
      planLength: lessonPlan.length,
      jsonLength: lessonJson.length,
    });
  } catch (error) {
    logger.error("Error in lesson generation", {error});
    res.write(`data: ${JSON.stringify({
      error: "Failed to generate lesson",
      details: error instanceof Error ? error.message : String(error),
    })}\n\n`);
    res.end();
  }
});

// Non-streaming version for simpler use cases
export const generateLessonSync = onRequest({cors: true}, async (req, res) => {
  // Only allow POST requests
  if (req.method !== "POST") {
    res.status(405).send({error: "Method not allowed. Use POST."});
    return;
  }

  // Validate request body
  const parseResult = GenerateLessonSchema.safeParse(req.body);
  if (!parseResult.success) {
    res.status(400).send({
      error: "Invalid request body",
      details: parseResult.error.issues,
    });
    return;
  }

  const {prompt, sourceText, estimatedMinutes} = parseResult.data;
  logger.info("Received sync lesson generation request", {
    promptLength: prompt.length,
    hasSourceText: !!sourceText,
  });

  const apiKey = process.env.GOOGLE_GENAI_API_KEY;
  if (!apiKey) {
    logger.error("GOOGLE_GENAI_API_KEY not configured");
    res.status(500).send({error: "API key not configured"});
    return;
  }

  let userMessage = `Create a ${estimatedMinutes}-minute ` +
    `interactive lesson about: ${prompt}`;

  if (sourceText) {
    userMessage +=
      `\n\nSource material:\n---\n${sourceText}\n---`;
  }

  const contents = [
    {
      role: "user",
      parts: [{text: LESSON_SYSTEM_PROMPT}],
    },
    {
      role: "model",
      parts: [{
        text: "I understand. I will generate lessons in the " +
          "exact JSON format specified.",
      }],
    },
    {
      role: "user",
      parts: [{text: userMessage}],
    },
  ];

  try {
    const response = await fetch(
      geminiGenerateUrl(apiKey),
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({
          contents,
          generationConfig: {
            temperature: 0.7,
            topP: 0.95,
            maxOutputTokens: 8192,
          },
        }),
      }
    );

    const data = await response.json();

    if (!response.ok) {
      logger.error("Gemini API error", {status: response.status, data});
      throw new Error(`Gemini API error: ${JSON.stringify(data)}`);
    }

    const text = data.candidates[0].content.parts[0].text;

    // Try to parse as JSON to validate
    let lessonJson;
    try {
      // Strip any markdown code block markers if present
      let cleanText = text.trim();
      if (cleanText.startsWith("```json")) {
        cleanText = cleanText.slice(7);
      } else if (cleanText.startsWith("```")) {
        cleanText = cleanText.slice(3);
      }
      if (cleanText.endsWith("```")) {
        cleanText = cleanText.slice(0, -3);
      }
      lessonJson = JSON.parse(cleanText.trim());
    } catch (parseError) {
      logger.error("Failed to parse lesson JSON", {parseError, text});
      res.status(500).send({
        error: "Generated content is not valid JSON",
        rawText: text,
      });
      return;
    }

    logger.info("Lesson generated successfully");
    res.status(200).send({lesson: lessonJson});
  } catch (error) {
    logger.error("Error generating lesson", {error});
    res.status(500).send({
      error: "Failed to generate lesson",
      details: error instanceof Error ? error.message : String(error),
    });
  }
});
