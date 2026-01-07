import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {z} from "zod";

// Validation schema for lesson generation request
const GenerateLessonSchema = z.object({
  prompt: z.string().min(1),
  sourceText: z.string().optional(),
  estimatedMinutes: z.number().min(5).max(60).optional().default(15),
});

// System prompt with JSON schema for lesson generation
const LESSON_SYSTEM_PROMPT = "You are an expert educational " +
  `content creator. Generate interactive lessons in JSON format.

IMPORTANT: Output ONLY valid JSON. ` +
  `No markdown code blocks, no explanations before or after.

Follow this exact JSON schema:

{
  "lessonId": "uuid-string",
  "title": "Lesson Title",
  "metadata": {
    "subject": "Subject Area",
    "estimatedMinutes": 15,
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

// Streaming lesson generation endpoint
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

  const {prompt, sourceText, estimatedMinutes} = parseResult.data;
  logger.info("Received lesson generation request", {
    promptLength: prompt.length,
    hasSourceText: !!sourceText,
    estimatedMinutes,
  });

  // Get API key from environment
  const apiKey = process.env.GOOGLE_GENAI_API_KEY;
  if (!apiKey) {
    logger.error("GOOGLE_GENAI_API_KEY not configured");
    res.status(500).send({error: "API key not configured"});
    return;
  }

  // Build user message
  let userMessage = `Create a ${estimatedMinutes}-minute ` +
    `interactive lesson about: ${prompt}`;

  if (sourceText) {
    userMessage += "\n\nSource material to base the lesson on:\n---\n" +
      `${sourceText}\n---\n\nFocus the lesson on the key concepts ` +
      "from this material.";
  }

  // Build Gemini request
  const contents = [
    {
      role: "user",
      parts: [{text: LESSON_SYSTEM_PROMPT}],
    },
    {
      role: "model",
      parts: [{
        text: "I understand. I will generate lessons in the exact " +
          "JSON format specified, with no additional text or " +
          "markdown formatting.",
      }],
    },
    {
      role: "user",
      parts: [{text: userMessage}],
    },
  ];

  // Set SSE headers
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");

  try {
    // Use gemini-2.5-flash for better structured output
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:streamGenerateContent?alt=sse&key=${apiKey}`,
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

    if (!response.ok) {
      const errorData = await response.text();
      logger.error("Gemini API error",
        {status: response.status, errorData});
      res.write(`data: ${JSON.stringify({
        error: "Gemini API error",
        details: errorData,
      })}\n\n`);
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
    let totalText = "";

    while (!streamDone) {
      const {done, value} = await reader.read();
      if (done) {
        streamDone = true;
        continue;
      }

      buffer += decoder.decode(value, {stream: true});

      // Parse SSE events from buffer
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";

      for (const line of lines) {
        if (line.startsWith("data: ")) {
          const jsonStr = line.slice(6);
          if (jsonStr.trim()) {
            try {
              const data = JSON.parse(jsonStr);
              const text =
                data.candidates?.[0]?.content?.parts?.[0]?.text;
              if (text) {
                totalText += text;
                // Send chunk to client
                res.write(`data: ${JSON.stringify({
                  chunk: text,
                  accumulated: totalText.length,
                })}\n\n`);
              }
            } catch {
              // Skip malformed JSON chunks
            }
          }
        }
      }
    }

    // Send completion signal with full text
    res.write(`data: ${JSON.stringify({done: true, fullText: totalText})}\n\n`);
    res.end();
    logger.info("Lesson generation completed", {totalLength: totalText.length});
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
      `https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
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
