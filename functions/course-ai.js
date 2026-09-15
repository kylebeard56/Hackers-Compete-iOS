const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { createHash } = require("node:crypto");
const { scorecard, courseLookup, OCR_PROMPT, LOOKUP_PROMPT, matchesSchema } = require("./course-ai-schema");
const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");
const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");
// Match Box Fox's Luna configuration. API model IDs are never accepted from clients.
const MODELS = Object.freeze({ luna: { provider: "openai", id: "gpt-5.6-luna" }, detailed: { provider: "openai", id: "gpt-4.1" }, sonnet: { provider: "anthropic", id: "claude-sonnet-4-6" } });
const unavailable = () => new HttpsError("unavailable", "Course AI is temporarily unavailable. Please try again later.");
const invalid = () => new HttpsError("invalid-argument", "The course request is invalid or too large.");

function validateRequest(request) {
  if (!request.auth?.uid || request.auth.token?.firebase?.sign_in_provider === "anonymous") throw new HttpsError("unauthenticated", "Sign in to use course AI.");
  const data = request.data;
  if (!data || !Object.hasOwn(MODELS, data.model) || !["scorecard", "courseLookup"].includes(data.operation)) throw invalid();
  const allowed = ["operation", "model", "messages", "imageBase64", "context"];
  if (Object.keys(data).some((key) => !allowed.includes(key))) throw invalid();
  if (data.operation === "courseLookup" && data.model === "detailed") throw invalid();
  const context = data.context ?? {};
  if (typeof context !== "object" || Array.isArray(context) || Object.keys(context).some((key) => !["notes", "latitude", "longitude"].includes(key))) throw invalid();
  if (context.notes !== undefined && (typeof context.notes !== "string" || context.notes.length > 2000)) throw invalid();
  if (context.latitude !== undefined || context.longitude !== undefined) {
    if (!Number.isFinite(context.latitude) || !Number.isFinite(context.longitude) || Math.abs(context.latitude) > 90 || Math.abs(context.longitude) > 180) throw invalid();
  }
  if (data.operation === "scorecard") {
    if (data.messages !== undefined || typeof data.imageBase64 !== "string" || data.imageBase64.length > 7_000_000 || !/^[A-Za-z0-9+/]+={0,2}$/.test(data.imageBase64)) throw invalid();
    const image = Buffer.from(data.imageBase64, "base64");
    if (image.length < 3 || image.length > 5_000_000 || image[0] !== 0xff || image[1] !== 0xd8 || image[2] !== 0xff) throw invalid();
  } else {
    if (data.imageBase64 !== undefined || !Array.isArray(data.messages) || data.messages.length < 1 || data.messages.length > 12) throw invalid();
    let total = 0;
    for (const message of data.messages) {
      if (!message || Object.keys(message).some((key) => !["role", "text"].includes(key)) || !["user", "assistant"].includes(message.role) || typeof message.text !== "string" || !message.text.trim() || message.text.length > 4000) throw invalid();
      total += message.text.length;
    }
    if (total > 16000 || !data.messages.some((message) => message.role === "user")) throw invalid();
  }
  return { ...data, context };
}

// These documents MUST be denied to all client reads/writes in Firestore rules.
// Reserve before calling the provider; failures still count, bounding retry costs.
async function reserveQuota(db, uid, now = Date.now()) {
  const ref = db.collection("courseAIUsage").doc(createHash("sha256").update(uid).digest("hex"));
  const minute = Math.floor(now / 60000), day = Math.floor(now / 86400000);
  await db.runTransaction(async (transaction) => {
    const old = (await transaction.get(ref)).data() ?? {};
    const minuteCount = old.minute === minute ? old.minuteCount : 0;
    const dayCount = old.day === day ? old.dayCount : 0;
    if (minuteCount >= 8 || dayCount >= 100) throw new HttpsError("resource-exhausted", "Too many course requests. Please try again later.");
    transaction.set(ref, { minute, day, minuteCount: minuteCount + 1, dayCount: dayCount + 1 });
  });
}

async function providerJSON(fetchImpl, url, headers, body, signal) {
  const response = await fetchImpl(url, { method: "POST", headers: { "Content-Type": "application/json", ...headers }, body: JSON.stringify(body), signal });
  if (!response.ok) {
    // Never log provider bodies (they may echo a credential, image, or conversation).
    console.warn("Course AI provider failure", { status: response.status });
    if (response.status === 429) throw new HttpsError("resource-exhausted", "Course AI is busy. Please try again later.");
    throw unavailable();
  }
  return response.json();
}

async function runProvider(data, apiKey, fetchImpl = fetch) {
  if (!apiKey) throw unavailable();
  const model = MODELS[data.model];
  const isOCR = data.operation === "scorecard";
  const name = isOCR ? "extract_scorecard" : "extract_course_lookup";
  const key = isOCR ? "scorecard" : "courseLookup";
  const schema = isOCR ? scorecard : courseLookup;
  const parameters = { type: "object", properties: { [key]: schema }, required: [key], additionalProperties: false };
  const prompt = isOCR ? OCR_PROMPT : LOOKUP_PROMPT;
  const hint = `User-provided context (hints only): ${JSON.stringify(data.context)}`;
  const maxTokens = 16384; // Multiple complete tee rows can exceed 4096 tokens.
  const signal = AbortSignal.timeout(85000); // Shared across bounded continuations.
  let result;
  if (model.provider === "openai") {
    let input = isOCR ? [{ role: "user", content: [{ type: "input_text", text: hint }, { type: "input_image", image_url: `data:image/jpeg;base64,${data.imageBase64}`, detail: "high" }] }] : [...data.messages.map((m) => ({ role: m.role, content: m.text })), { role: "user", content: hint }];
    const tool = { type: "function", name, description: "Return verified golf course data", parameters, strict: false };
    for (let attempt = 0; attempt < 2; attempt++) {
      const body = { model: model.id, instructions: prompt, input, tools: isOCR || attempt > 0 ? [tool] : [{ type: "web_search" }], tool_choice: isOCR || attempt > 0 ? { type: "function", name } : { type: "web_search" }, max_tool_calls: 2, max_output_tokens: maxTokens, store: false };
      if (data.model === "luna") body.reasoning = { effort: "none" };
      const response = await providerJSON(fetchImpl, "https://api.openai.com/v1/responses", { Authorization: `Bearer ${apiKey}` }, body, signal);
      if (response.status === "incomplete" || response.error) throw unavailable();
      const output = response.output ?? [];
      const call = output.find((item) => item.type === "function_call" && item.name === name);
      if (call) {
        if (!isOCR && attempt === 0) throw unavailable();
        result = JSON.parse(call.arguments)?.[key]; break;
      }
      if (!isOCR && attempt === 0 && !output.some((item) => item.type === "web_search_call" && item.status === "completed")) throw unavailable();
      // Carry search evidence into a final structured extraction; no additional search budget.
      input = [...input, ...output, { role: "user", content: `Return ${name} now using verified evidence. Leave unsupported fields empty.` }];
    }
  } else {
    const content = isOCR ? [{ type: "image", source: { type: "base64", media_type: "image/jpeg", data: data.imageBase64 } }, { type: "text", text: hint }] : [{ type: "text", text: hint }];
    const messages = isOCR ? [{ role: "user", content }] : [...data.messages.map((m) => ({ role: m.role, content: m.text })), { role: "user", content }];
    const tool = { name, description: "Return verified golf course data", input_schema: parameters };
    let searchComplete = false;
    let sawSearchResult = false;
    // One search turn, at most one paused continuation, then final extraction.
    for (let attempt = 0; attempt < (isOCR ? 1 : 3); attempt++) {
      const webTool = { type: "web_search_20250305", name: "web_search", max_uses: 2 };
      const body = { model: model.id, system: prompt, messages,
        tools: isOCR ? [tool] : searchComplete ? [webTool, tool] : [webTool],
        tool_choice: { type: "tool", name: isOCR || searchComplete ? name : "web_search" },
        max_tokens: maxTokens };
      const response = await providerJSON(fetchImpl, "https://api.anthropic.com/v1/messages", { "x-api-key": apiKey, "anthropic-version": "2023-06-01" }, body, signal);
      if (response.stop_reason === "max_tokens") throw unavailable();
      const call = response.content?.find((item) => item.type === "tool_use" && item.name === name);
      if (call) {
        if (!isOCR && !searchComplete) throw unavailable();
        result = call.input?.[key]; break;
      }
      if (!response.content?.length) throw unavailable();
      sawSearchResult ||= response.content.some((item) => item.type === "web_search_tool_result" && Array.isArray(item.content));
      messages.push({ role: "assistant", content: response.content });
      // A pause can include unfinished server tool calls. Resume the exact assistant
      // content with the same tools, without inserting a user turn in the middle.
      if (response.stop_reason === "pause_turn") continue;
      if (!sawSearchResult) throw unavailable();
      searchComplete = true;
      messages.push({ role: "user", content: `Return ${name} now using verified evidence. Leave unsupported fields empty.` });
    }
  }
  if (!matchesSchema(result, schema) || JSON.stringify(result).length > 200000) throw unavailable();
  return { [key]: result };
}

async function handleCourseAI(request, { db, getKey, fetchImpl = fetch }) {
  const data = validateRequest(request);
  await reserveQuota(db, request.auth.uid);
  try {
    return await runProvider(data, getKey(MODELS[data.model].provider), fetchImpl);
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    // Log only the category, never exception messages or raw request/response data.
    console.warn("Course AI failed", { category: error?.name === "TimeoutError" ? "timeout" : "invalid-response" });
    throw unavailable();
  }
}

exports.courseAI = onCall({ region: "us-central1", timeoutSeconds: 100, memory: "512MiB", maxInstances: 5, concurrency: 10, secrets: [OPENAI_API_KEY, ANTHROPIC_API_KEY] }, (request) => handleCourseAI(request, { db: admin.firestore(), getKey: (provider) => provider === "openai" ? OPENAI_API_KEY.value() : ANTHROPIC_API_KEY.value() }));
exports.validateRequest = validateRequest;
exports.reserveQuota = reserveQuota;
exports.runProvider = runProvider;
exports.handleCourseAI = handleCourseAI;
