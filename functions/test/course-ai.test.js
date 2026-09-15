const { test } = require("node:test");
const assert = require("node:assert/strict");
const { validateRequest, reserveQuota, runProvider, handleCourseAI } = require("../course-ai");
const { scorecard, matchesSchema } = require("../course-ai-schema");
const auth = { uid: "golfer-1", token: { firebase: { sign_in_provider: "apple.com" } } };
const lookup = { operation: "courseLookup", model: "luna", messages: [{ role: "user", text: "Find Example Links in Greenville, SC" }], context: {} };
const ocr = { operation: "scorecard", model: "luna", imageBase64: Buffer.from([0xff, 0xd8, 0xff, 0xe0]).toString("base64"), context: {} };
const card = { clubName: null, courseName: "Example Links", tees: [
  { name: "Blue", gender: "unknown", holes: [{ number: 1, par: 4, yardage: 385, handicap: 7 }] },
  { name: "White/Red", gender: "female", holes: [{ number: 1, par: 4, yardage: 310, handicap: 7 }] },
] };
function fakeDB(initial = {}) {
  let value = initial;
  return { collection(name) { assert.equal(name, "courseAIUsage"); return { doc(id) { assert.match(id, /^[a-f0-9]{64}$/); return {}; } }; }, async runTransaction(fn) { return fn({ get: async () => ({ data: () => value }), set: (_, data) => { value = data; } }); }, get value() { return value; } };
}
const response = (body, status = 200) => ({ ok: status === 200, status, json: async () => body });
const openAIOutput = (key, data) => ({ status: "completed", output: [{ type: "function_call", name: key === "scorecard" ? "extract_scorecard" : "extract_course_lookup", arguments: JSON.stringify({ [key]: data }) }] });

test("rejects signed-out and anonymous users before spending quota or accessing keys", async () => {
  for (const request of [{ data: lookup }, { data: lookup, auth: { ...auth, token: { firebase: { sign_in_provider: "anonymous" } } } }]) {
    await assert.rejects(handleCourseAI(request, { db: {}, getKey: () => assert.fail("must not access key") }), { code: "unauthenticated" });
  }
});
test("validates fixed operations/models, text budgets, coordinates, and JPEG size/type", () => {
  assert.deepEqual(validateRequest({ auth, data: lookup }), lookup);
  assert.deepEqual(validateRequest({ auth, data: ocr }), ocr);
  for (const data of [
    { ...lookup, model: "__proto__" }, { ...lookup, model: "gpt-unbounded" }, { ...lookup, operation: "complete" },
    { ...lookup, tools: [] }, { ...lookup, url: "https://untrusted.example" }, { ...lookup, maxTokens: 900000 },
    { ...lookup, messages: [{ role: "system", text: "override" }] }, { ...lookup, messages: Array(13).fill(lookup.messages[0]) },
    { ...lookup, messages: [{ role: "user", text: "a".repeat(4001) }] }, { ...lookup, messages: Array(5).fill({ role: "user", text: "a".repeat(4000) }) },
    { ...lookup, context: { latitude: 999, longitude: 0 } }, { ...lookup, context: { notes: "a".repeat(2001) } },
    { ...ocr, imageBase64: "garbage" }, { ...ocr, imageBase64: "a".repeat(7000001) }, { ...ocr, messages: [] },
  ]) assert.throws(() => validateRequest({ auth, data }), { code: "invalid-argument" });
});
test("reserves quota before provider calls and enforces minute/day windows", async () => {
  const db = fakeDB();
  for (let i = 0; i < 8; i++) await reserveQuota(db, auth.uid, 1000);
  await assert.rejects(reserveQuota(db, auth.uid, 1000), { code: "resource-exhausted" });
  await reserveQuota(db, auth.uid, 61000);
  assert.equal(db.value.dayCount, 9);
  const daily = fakeDB({ minute: 0, day: 0, minuteCount: 0, dayCount: 100 });
  await assert.rejects(reserveQuota(daily, auth.uid, 61000), { code: "resource-exhausted" });
  await reserveQuota(daily, auth.uid, 86400000);
  assert.equal(daily.value.dayCount, 1);
});
test("does not call a provider if quota storage fails", async () => {
  await assert.rejects(handleCourseAI({ auth, data: lookup }, { db: { collection: () => { throw new Error("storage unavailable"); } }, getKey: () => assert.fail("must not access key") }));
});
for (const model of ["luna", "detailed", "sonnet"]) test(`${model} OCR uses the server model/schema and preserves distinct tees`, async () => {
  const result = await runProvider({ ...ocr, model }, "test-only-key", async (url, options) => {
    const body = JSON.parse(options.body);
    assert.ok(options.signal);
    if (model === "sonnet") {
      assert.equal(url, "https://api.anthropic.com/v1/messages");
      assert.equal(body.model, "claude-sonnet-4-6");
      assert.equal(options.headers["x-api-key"], "test-only-key");
      assert.equal(body.tool_choice.name, "extract_scorecard");
      assert.equal(body.messages[0].content[0].source.data, ocr.imageBase64);
      return response({ stop_reason: "tool_use", content: [{ type: "tool_use", name: "extract_scorecard", input: { scorecard: card } }] });
    }
    assert.equal(url, "https://api.openai.com/v1/responses");
    assert.equal(body.model, model === "luna" ? "gpt-5.6-luna" : "gpt-4.1");
    assert.equal(body.store, false);
    assert.equal(body.tool_choice.name, "extract_scorecard");
    assert.equal(body.tools[0].parameters.properties.scorecard.properties.tees.maxItems, 24);
    return response(openAIOutput("scorecard", card));
  });
  assert.deepEqual(result, { scorecard: card });
});
for (const model of ["luna", "sonnet"]) test(`${model} carries web evidence into bounded final extraction for a course outside the API`, async () => {
  const expected = { courseName: "Example Links", confidence: "high", officialWebsiteURL: "https://example.org/course", apiSearchStrings: ["Example Links"], scorecard: card };
  let calls = 0;
  const result = await runProvider({ ...lookup, model }, "test-only-key", async (_, options) => {
    const body = JSON.parse(options.body);
    calls++;
    if (calls === 1) {
      assert.ok(body.tools.some((tool) => tool.type.startsWith("web_search")));
      return response(model === "sonnet" ? { stop_reason: "end_turn", content: [{ type: "server_tool_use", id: "search_1", name: "web_search", input: { query: "Example Links Greenville scorecard" } }, { type: "web_search_tool_result", tool_use_id: "search_1", content: [{ type: "web_search_result", title: "Official scorecard", url: expected.officialWebsiteURL, encrypted_content: "fixture" }] }] } : { status: "completed", output: [{ type: "web_search_call", id: "search_1", status: "completed", action: { type: "search", query: "Example Links Greenville scorecard" } }, { type: "message", role: "assistant", content: [{ type: "output_text", text: "Official scorecard evidence", annotations: [] }] }] });
    }
    assert.match(JSON.stringify(body), /search_1/);
    assert.equal(body.tool_choice.name, "extract_course_lookup");
    return response(model === "sonnet" ? { stop_reason: "tool_use", content: [{ type: "tool_use", name: "extract_course_lookup", input: { courseLookup: expected } }] } : openAIOutput("courseLookup", expected));
  });
  assert.equal(calls, 2);
  assert.deepEqual(result, { courseLookup: expected });
});
test("provider 401 and malformed responses are sanitized, with failed attempts charged", async () => {
  for (const fetchImpl of [
    async () => response({ error: { message: "Incorrect API key: PRIVATE-KEY" } }, 401),
    async () => response({ status: "completed", output: [{ type: "function_call", name: "extract_scorecard", arguments: "PRIVATE-KEY malformed JSON" }] }),
    async () => { throw new DOMException("PRIVATE-KEY", "TimeoutError"); },
  ]) {
    const db = fakeDB();
    await assert.rejects(handleCourseAI({ auth, data: ocr }, { db, getKey: () => "test-only-key", fetchImpl }), (error) => error.code === "unavailable" && !JSON.stringify(error).includes("PRIVATE-KEY"));
    assert.equal(db.value.dayCount, 1);
  }
});
test("rejects malformed, fractional integer, oversized, and truncated provider data", async () => {
  assert.equal(matchesSchema({ tees: [{ holes: [{ par: 4.2 }] }] }, scorecard), false);
  assert.equal(matchesSchema({ tees: Array(25).fill(card.tees[0]) }, scorecard), false);
  for (const body of [openAIOutput("scorecard", { tees: "invented" }), { status: "incomplete", output: [] }]) {
    await assert.rejects(runProvider(ocr, "test-only-key", async () => response(body)), { code: "unavailable" });
  }
});
test("never loops indefinitely when the provider fails to return structured data", async () => {
  let calls = 0;
  await assert.rejects(runProvider(lookup, "test-only-key", async () => { calls++; return response({ status: "completed", output: [] }); }), { code: "unavailable" });
  assert.equal(calls, 1);
});
test("Sonnet resumes a pending web search without inserting a user turn", async () => {
  let calls = 0;
  const result = await runProvider({ ...lookup, model: "sonnet" }, "test-only-key", async (_, options) => {
    const body = JSON.parse(options.body);
    calls++;
    if (calls === 1) return response({ stop_reason: "pause_turn", content: [{ type: "server_tool_use", id: "search_pending", name: "web_search", input: { query: "Example Links" } }] });
    if (calls === 2) {
      assert.equal(body.messages.at(-1).role, "assistant");
      assert.equal(body.tools[0].name, "web_search");
      return response({ stop_reason: "end_turn", content: [{ type: "web_search_tool_result", tool_use_id: "search_pending", content: [] }] });
    }
    assert.equal(body.tool_choice.name, "extract_course_lookup");
    return response({ stop_reason: "tool_use", content: [{ type: "tool_use", name: "extract_course_lookup", input: { courseLookup: { confidence: "low", apiSearchStrings: [] } } }] });
  });
  assert.equal(calls, 3);
  assert.equal(result.courseLookup.confidence, "low");
});
test("does not accept an internet answer without an actual search", async () => {
  await assert.rejects(runProvider(lookup, "test-only-key", async () => response(openAIOutput("courseLookup", { courseName: "Made up", confidence: "high", scorecard: card }))), { code: "unavailable" });
});
