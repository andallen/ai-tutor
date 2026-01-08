import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {z} from "zod";
import {geminiGenerateUrl} from "./config";

// Validation schema for answer comparison request
const CompareAnswerSchema = z.object({
  userAnswer: z.string().min(1),
  correctAnswer: z.string().min(1),
  questionType: z.enum(["multipleChoice", "freeResponse", "math"]),
  questionPrompt: z.string().min(1),
  explanation: z.string().optional(),
});

// System prompt for answer comparison
const ANSWER_COMPARISON_PROMPT = "You are an educational AI assistant " +
  `that evaluates student answers.

Your task is to compare a student's answer to the correct answer ` +
  `and provide constructive feedback.

IMPORTANT: Output ONLY valid JSON. No markdown, no explanations before or after.

Output format:
{
  "isCorrect": true/false,
  "feedback": "Detailed feedback message",
  "acceptedReason": "Optional explanation if alternative answer was accepted"
}

Guidelines:
1. Be fair and recognize semantically equivalent answers
2. For math, accept equivalent forms ` +
  `(different notation, reordered terms, etc.)
3. For free response, focus on key concepts ` +
  `rather than exact wording
4. If the answer is partially correct, ` +
  `mark as incorrect but explain what's right and what's missing
5. Provide constructive, educational feedback
6. If you accept an alternative answer, explain why in acceptedReason
7. Be encouraging even when marking answers incorrect`;

// Answer comparison endpoint
export const compareAnswer = onRequest({cors: true}, async (req, res) => {
  // Only allow POST requests
  if (req.method !== "POST") {
    res.status(405).send({error: "Method not allowed. Use POST."});
    return;
  }

  // Validate request body
  const parseResult = CompareAnswerSchema.safeParse(req.body);
  if (!parseResult.success) {
    res.status(400).send({
      error: "Invalid request body",
      details: parseResult.error.issues,
    });
    return;
  }

  const {userAnswer, correctAnswer, questionType, questionPrompt, explanation} =
    parseResult.data;

  logger.info("Received answer comparison request", {
    questionType,
    userAnswerLength: userAnswer.length,
    correctAnswerLength: correctAnswer.length,
  });

  // For multiple choice, do direct comparison
  if (questionType === "multipleChoice") {
    const isCorrect = userAnswer.trim().toLowerCase() ===
      correctAnswer.trim().toLowerCase();

    const feedback = isCorrect ?
      "Correct! " + (explanation || "") :
      `Not quite. The correct answer is: ${correctAnswer}. ` +
      `${explanation || ""}`;

    res.status(200).send({
      isCorrect,
      feedback: feedback.trim(),
    });
    return;
  }

  // For freeResponse and math, use AI comparison
  const apiKey = process.env.GOOGLE_GENAI_API_KEY;
  if (!apiKey) {
    logger.error("GOOGLE_GENAI_API_KEY not configured");
    res.status(500).send({error: "API key not configured"});
    return;
  }

  // Build the comparison prompt
  const comparisonMessage = `Question: ${questionPrompt}

Student's Answer:
${userAnswer}

Correct Answer:
${correctAnswer}

${explanation ? `Additional Context: ${explanation}` : ""}

Question Type: ${questionType}

Evaluate the student's answer and provide feedback in JSON format.`;

  const contents = [
    {
      role: "user",
      parts: [{text: ANSWER_COMPARISON_PROMPT}],
    },
    {
      role: "model",
      parts: [{
        text: "I understand. I will evaluate student answers " +
          "fairly and provide feedback in JSON format only.",
      }],
    },
    {
      role: "user",
      parts: [{text: comparisonMessage}],
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
            temperature: 0.3, // Lower temperature for consistent evaluation
            topP: 0.95,
            maxOutputTokens: 1024,
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

    // Parse the JSON response
    let comparisonResult;
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
      comparisonResult = JSON.parse(cleanText.trim());
    } catch (parseError) {
      logger.error("Failed to parse comparison JSON", {parseError, text});
      // Fallback: provide generic feedback
      res.status(200).send({
        isCorrect: false,
        feedback: "Unable to evaluate answer. Please try again.",
      });
      return;
    }

    // Validate the response structure
    if (typeof comparisonResult.isCorrect !== "boolean" ||
        typeof comparisonResult.feedback !== "string") {
      logger.error("Invalid comparison result structure", {comparisonResult});
      res.status(200).send({
        isCorrect: false,
        feedback: "Unable to evaluate answer. Please try again.",
      });
      return;
    }

    logger.info("Answer comparison completed", {
      isCorrect: comparisonResult.isCorrect,
    });

    res.status(200).send({
      isCorrect: comparisonResult.isCorrect,
      feedback: comparisonResult.feedback,
      acceptedReason: comparisonResult.acceptedReason,
    });
  } catch (error) {
    logger.error("Error comparing answer", {error});
    res.status(500).send({
      error: "Failed to compare answer",
      details: error instanceof Error ? error.message : String(error),
    });
  }
});
