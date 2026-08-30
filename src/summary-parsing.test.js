// Run with: npm test (from src/), or: node --test src/summary-parsing.test.js
//
// Node's built-in runner, so this adds no dependency to a bundle that ships to
// Lambda. Nothing in CI runs it: .github/workflows/deploy.yml only deploys.
//
// What is being protected: case_summaries.summary holds plain markdown, and a
// summary that could not be parsed used to be written to that column raw. Two
// of seventeen rows held a literal `{"summary": "## Case ...` string as a
// result, and one of them broke again on a later regenerate, so this is a
// recurring failure rather than a historical one.

import assert from "node:assert/strict";
import test from "node:test";
import { extractSummaryText, stripCodeFence } from "./summary-parsing.js";

const MARKDOWN = "## Case summary\n\nAlexandros is mid-filing.\n\n- E1 outstanding";

test("plain markdown is stored as written", () => {
    assert.equal(extractSummaryText(MARKDOWN), MARKDOWN);
});

test("a JSON envelope yields the summary, not the envelope", () => {
    const raw = JSON.stringify({ summary: MARKDOWN });
    assert.equal(extractSummaryText(raw), MARKDOWN);
});

test("a fenced JSON envelope yields the summary", () => {
    const raw = "```json\n" + JSON.stringify({ summary: MARKDOWN }) + "\n```";
    assert.equal(extractSummaryText(raw), MARKDOWN);
});

test("fenced markdown keeps its markdown, fence removed", () => {
    assert.equal(extractSummaryText("```markdown\n" + MARKDOWN + "\n```"), MARKDOWN);
    assert.equal(extractSummaryText("```\n" + MARKDOWN + "\n```"), MARKDOWN);
});

test("a truncated envelope throws rather than being stored raw", () => {
    // The real failure: maxTokens cuts the envelope mid-string, so it cannot
    // parse. Storing this is what produced the unreadable rows.
    const truncated = '{"summary": "## Case summary\\n\\nAlexandros is mid-fil';
    assert.throws(() => extractSummaryText(truncated), /does not parse/);
});

test("an envelope with no summary field throws", () => {
    assert.throws(() => extractSummaryText('{"draft": "wrong shape"}'), /no usable summary/);
});

test("an empty response throws", () => {
    for (const empty of ["", "   ", "```json\n```"]) {
        assert.throws(() => extractSummaryText(empty), /empty summary/);
    }
});

test("markdown containing braces is not mistaken for an envelope", () => {
    // A summary may quote JSON or use braces in prose. It must survive intact.
    const withBraces =
        "## Case summary\n\nThe payload was `{\"afm\": \"164334680\"}` which AADE rejected.";
    assert.equal(extractSummaryText(withBraces), withBraces);
});

test("prose wrapping a real envelope still yields the summary", () => {
    const raw = "Here is the summary:\n" + JSON.stringify({ summary: MARKDOWN });
    assert.equal(extractSummaryText(raw), MARKDOWN);
});

test("the exact shape found in the two broken rows is refused", () => {
    // Reconstructed from the stored value: an envelope whose newlines are
    // escaped, that failed to parse and was written verbatim.
    const broken = '{"summary": "## Case Summary\\n\\nBrendan McInerney\\n\\n- ENFIA';
    assert.throws(() => extractSummaryText(broken), /Refusing to store it/);
});

test("stripCodeFence leaves unfenced text alone", () => {
    assert.equal(stripCodeFence(MARKDOWN), MARKDOWN);
});
