import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {z} from "zod";
import {geminiGenerateUrl} from "./config";

// Validation schema for lesson plan generation request.
const GenerateLessonPlanSchema = z.object({
  prompt: z.string().min(1),
  sourceText: z.string().optional(),
});

// Progress callback type for reporting step progress.
export type ProgressCallback = (status: string, name: string) => void;

/**
 * Helper to call Gemini and get text response.
 * Exported for use in other modules.
 * @param {string} apiKey - The Gemini API key.
 * @param {string} prompt - The prompt to send.
 * @return {Promise<string>} The generated text.
 */
export async function callGemini(
  apiKey: string,
  prompt: string
): Promise<string> {
  const contents = [
    {role: "user", parts: [{text: prompt}]},
  ];

  const response = await fetch(geminiGenerateUrl(apiKey), {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      contents,
      generationConfig: {
        temperature: 0.7,
        topP: 0.95,
      },
    }),
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Gemini API error: ${JSON.stringify(data)}`);
  }

  return data.candidates[0].content.parts[0].text;
}

/**
 * Learning Objectives: What should the learner know/do after this lesson?
 * @param {string} topic - The lesson topic.
 * @param {string} sourceText - Optional source material.
 * @return {string} The prompt.
 */
function buildObjectivesPrompt(topic: string, sourceText?: string): string {
  if (sourceText) {
    return `You are an expert curriculum designer.

Given this source material:
---
${sourceText}
---

The user wants to learn: "${topic}"

Extract 3-5 specific, measurable learning objectives based ONLY on what is
covered in the source material. Do not add objectives about topics not
present in the source.

Rules:
- Use action verbs (explain, identify, compare, calculate, etc.)
- Each objective should be testable
- Order from foundational to advanced

Output format:
LEARNING OBJECTIVES:
- [Objective]
- [Objective]
- [Objective]`;
  }

  return `You are an expert curriculum designer.

Given the topic: "${topic}"

Identify 3-5 specific, measurable learning objectives for someone learning
this topic.

Rules:
- Use action verbs (explain, identify, compare, calculate, etc.)
- Each objective should be testable
- Order from foundational to advanced

Output format:
LEARNING OBJECTIVES:
- [Objective]
- [Objective]
- [Objective]`;
}

/**
 * Prerequisites: What must the learner already know before starting?
 * @param {string} topic - The lesson topic.
 * @param {string|undefined} sourceText - Optional source material.
 * @return {string} The prompt.
 */
function buildPrerequisitesPrompt(
  topic: string,
  sourceText?: string
): string {
  if (sourceText) {
    return `You are an expert curriculum designer.

Given this source material:
---
${sourceText}
---

The user wants to learn: "${topic}"

What prior knowledge must the learner already have before starting to learn
this material?

Rules:
- List 3-5 prerequisites
- Be specific (not "basic math" but "understanding of fractions")
- Only include true prerequisites, not nice-to-haves
- Base prerequisites on what the source material assumes

Output format:
PREREQUISITES:
- [Prior knowledge item]
- [Prior knowledge item]
- [Prior knowledge item]`;
  }

  return `You are an expert curriculum designer.

Given the topic: "${topic}"

What prior knowledge must the learner already have before starting to learn
this topic?

Rules:
- List 3-5 prerequisites
- Be specific (not "basic math" but "understanding of fractions")
- Only include true prerequisites, not nice-to-haves

Output format:
PREREQUISITES:
- [Prior knowledge item]
- [Prior knowledge item]
- [Prior knowledge item]`;
}

/**
 * Core Concepts: What are the key ideas and how do they relate?
 * @param {string} topic - The lesson topic.
 * @param {string|undefined} sourceText - Optional source material.
 * @return {string} The prompt.
 */
function buildConceptsPrompt(
  topic: string,
  sourceText?: string
): string {
  if (sourceText) {
    return `You are an expert curriculum designer.

Given this source material:
---
${sourceText}
---

The user wants to learn: "${topic}"

Extract 3-6 core concepts from the source material. For each concept, specify
which other concepts it depends on (if any).

Rules:
- ONLY use information present in the source material
- Do NOT add concepts from external knowledge
- Each concept should be a single, coherent idea from the source
- Order concepts so dependencies come first
- Use descriptive concept names (e.g., "Energy Transfer" not "Concept A")

Output format:
CONCEPTS:

[Concept Name]
Depends on: None
Core idea: [1-2 sentence summary from source]

[Concept Name]
Depends on: [Previous concept name if applicable, or None]
Core idea: [1-2 sentence summary from source]

[Concept Name]
Depends on: [Previous concept names if applicable, or None]
Core idea: [1-2 sentence summary from source]`;
  }

  return `You are an expert curriculum designer.

Given the topic: "${topic}"

Identify 3-6 core concepts that must be taught for someone to understand this
topic. For each concept, specify which other concepts it depends on (if any).

Rules:
- Each concept should be a single, coherent idea
- Order concepts so dependencies come first
- Use descriptive concept names (e.g., "Energy Transfer" not "Concept A")

Output format:
CONCEPTS:

[Concept Name]
Depends on: None
Core idea: [1-2 sentence summary]

[Concept Name]
Depends on: [Previous concept name if applicable, or None]
Core idea: [1-2 sentence summary]

[Concept Name]
Depends on: [Previous concept names if applicable, or None]
Core idea: [1-2 sentence summary]`;
}

/**
 * Misconceptions: What do learners commonly get wrong?
 * @param {string} topic - The lesson topic.
 * @param {string|undefined} sourceText - Optional source material.
 * @return {string} The prompt.
 */
function buildMisconceptionsPrompt(
  topic: string,
  sourceText?: string
): string {
  if (sourceText) {
    return `You are an expert educator.

Given this source material:
---
${sourceText}
---

The user wants to learn: "${topic}"

Identify 3-5 common misconceptions that learners typically have when learning
this material. For each misconception, explain what's wrong and why.

Rules:
- Base misconceptions on typical errors for this type of content
- Be specific about what the misconception is
- Explain why it's wrong and what the correct understanding is

Output format:
MISCONCEPTIONS:

[Topic/Concept area]
- Misconception: [What learners often wrongly believe]
- Why it's wrong: [Brief explanation of correct understanding]

[Topic/Concept area]
- Misconception: [What learners often wrongly believe]
- Why it's wrong: [Brief explanation of correct understanding]`;
  }

  return `You are an expert educator who has taught "${topic}" many times.

Identify 3-5 common misconceptions that learners typically have when learning
this topic. For each misconception, explain what's wrong and why.

Rules:
- Be specific about what the misconception is
- Explain why it's wrong and what the correct understanding is
- These should be real, documented misconceptions (not made up)

Output format:
MISCONCEPTIONS:

[Topic/Concept area]
- Misconception: [What learners often wrongly believe]
- Why it's wrong: [Brief explanation of correct understanding]

[Topic/Concept area]
- Misconception: [What learners often wrongly believe]
- Why it's wrong: [Brief explanation of correct understanding]`;
}

/**
 * Assessment Angles: How can we test understanding?
 * @param {string} topic - The lesson topic.
 * @param {string|undefined} sourceText - Optional source material.
 * @return {string} The prompt.
 */
function buildAssessmentPrompt(
  topic: string,
  sourceText?: string
): string {
  if (sourceText) {
    return `You are an expert assessment designer.

Given this source material:
---
${sourceText}
---

The user wants to learn: "${topic}"

Suggest 6-10 ways to test whether a learner understood the key concepts in
this material. Group them by the concept/topic area they assess.

Rules:
- Vary question types (factual recall, application, comparison, etc.)
- Questions should directly test concepts from the source material
- Be specific enough that someone could write the actual question

Output format:
ASSESSMENT ANGLES:

[Concept/Topic area]
- [Assessment approach]
- [Assessment approach]

[Concept/Topic area]
- [Assessment approach]
- [Assessment approach]`;
  }

  return `You are an expert assessment designer.

Given the topic: "${topic}"

Suggest 6-10 ways to test whether a learner understood the key concepts in
this topic. Group them by the concept/topic area they assess.

Rules:
- Vary question types (factual recall, application, comparison, etc.)
- Questions should directly test the core concepts, not tangential knowledge
- Be specific enough that someone could write the actual question

Output format:
ASSESSMENT ANGLES:

[Concept/Topic area]
- [Assessment approach]
- [Assessment approach]

[Concept/Topic area]
- [Assessment approach]
- [Assessment approach]`;
}

/**
 * Synthesis: Combine all outputs into a structured lesson plan.
 * @param {string} topic - The lesson topic.
 * @param {string|undefined} sourceText - Optional source material.
 * @param {string} objectives - Learning objectives output.
 * @param {string} prerequisites - Prerequisites output.
 * @param {string} concepts - Core concepts output.
 * @param {string} misconceptions - Misconceptions output.
 * @param {string} assessment - Assessment angles output.
 * @return {string} The prompt for synthesis.
 */
function buildSynthesisPrompt(
  topic: string,
  sourceText: string | undefined,
  objectives: string,
  prerequisites: string,
  concepts: string,
  misconceptions: string,
  assessment: string
): string {
  const source = sourceText ? "User-provided document" : "AI Knowledge";

  return `You are an expert curriculum designer creating a structured lesson
plan.

Compile the following into a single, well-formatted lesson plan document:

TOPIC: ${topic}
SOURCE: ${source}

${objectives}

${prerequisites}

${concepts}

${misconceptions}

${assessment}

Create the final lesson plan following this exact format:

# LESSON PLAN: [Topic Title]

## METADATA
- Estimated Duration: [estimate based on concept count, ~5 min per concept]
- Source: [AI Knowledge / User-Provided Document]

---

## LEARNING OBJECTIVES

By the end of this lesson, the learner will be able to:

[numbered list from objectives]

---

## PREREQUISITES

This lesson assumes the learner already understands:

[bullet list from prerequisites]

---

## CONCEPT PROGRESSION

[For each concept, create a section with this structure:]

### [Concept Name]
**Depends on**: [dependencies or "None (foundational)"]

**Core Knowledge**:
[Expand the core idea into 2-4 paragraphs of educational content]

**Key Insight**:
[The central "aha" moment for this concept]

**Common Misconception**:
[Match relevant misconception from the misconceptions list]

**Assessment Angles**:
[Match relevant assessment approaches from the assessment list]

---

## SUGGESTED PROGRESSION

[Order the concepts logically based on dependencies]

[Brief narrative explaining why this order makes sense]

---

## SUMMARY POINTS

Key takeaways for the learner:

[3-5 bullet points summarizing the most important ideas]`;
}

/**
 * Core lesson plan generation logic.
 * Runs the 6-step pipeline and returns the structured markdown lesson plan.
 * Can be called directly without HTTP handling.
 * @param {string} apiKey - The Gemini API key.
 * @param {string} topic - The lesson topic.
 * @param {string|undefined} sourceText - Optional source material.
 * @param {ProgressCallback|undefined} onProgress - Optional progress callback.
 * @return {Promise<string>} The generated lesson plan markdown.
 */
export async function generateLessonPlanCore(
  apiKey: string,
  topic: string,
  sourceText?: string,
  onProgress?: ProgressCallback
): Promise<string> {
  // Report progress helper.
  const report = (status: string, name: string) => {
    if (onProgress) {
      onProgress(status, name);
    }
  };

  // Run all 5 analysis steps in parallel.
  report("running", "Analyzing topic");

  const [objectives, prerequisites, concepts, misconceptions, assessment] =
    await Promise.all([
      callGemini(apiKey, buildObjectivesPrompt(topic, sourceText)),
      callGemini(apiKey, buildPrerequisitesPrompt(topic, sourceText)),
      callGemini(apiKey, buildConceptsPrompt(topic, sourceText)),
      callGemini(apiKey, buildMisconceptionsPrompt(topic, sourceText)),
      callGemini(apiKey, buildAssessmentPrompt(topic, sourceText)),
    ]);

  report("complete", "Analysis complete");

  // Synthesis: Combine all outputs into final lesson plan.
  report("running", "Synthesizing Lesson Plan");
  const lessonPlan = await callGemini(
    apiKey,
    buildSynthesisPrompt(
      topic, sourceText, objectives, prerequisites,
      concepts, misconceptions, assessment
    )
  );
  report("complete", "Synthesis complete");

  return lessonPlan;
}

/**
 * Main lesson plan generation endpoint with SSE streaming.
 * Implements a 6-step pipeline for structured lesson planning.
 */
export const generateLessonPlan = onRequest({cors: true}, async (req, res) => {
  // Only allow POST requests.
  if (req.method !== "POST") {
    res.status(405).send({error: "Method not allowed. Use POST."});
    return;
  }

  // Validate request body.
  const parseResult = GenerateLessonPlanSchema.safeParse(req.body);
  if (!parseResult.success) {
    res.status(400).send({
      error: "Invalid request body",
      details: parseResult.error.issues,
    });
    return;
  }

  const {prompt, sourceText} = parseResult.data;
  const hasSource = !!sourceText;

  logger.info("Received lesson plan generation request", {
    promptLength: prompt.length,
    hasSourceText: hasSource,
  });

  // Get API key from environment.
  const apiKey = process.env.GOOGLE_GENAI_API_KEY;
  if (!apiKey) {
    logger.error("GOOGLE_GENAI_API_KEY not configured");
    res.status(500).send({error: "API key not configured"});
    return;
  }

  // Set SSE headers for streaming progress.
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");

  try {
    // Use the core function with SSE progress reporting.
    const lessonPlan = await generateLessonPlanCore(
      apiKey,
      prompt,
      sourceText,
      (status, name) => {
        res.write(`data: ${JSON.stringify({status, name})}\n\n`);
      }
    );

    // Send final result.
    res.write(`data: ${JSON.stringify({done: true, lessonPlan})}\n\n`);
    res.end();

    logger.info("Lesson plan generated successfully", {
      prompt,
      hasSource,
      planLength: lessonPlan.length,
    });
  } catch (error) {
    logger.error("Error generating lesson plan", {error});
    const errorMsg = error instanceof Error ? error.message : "Unknown error";
    res.write(`data: ${JSON.stringify({error: errorMsg})}\n\n`);
    res.end();
  }
});
