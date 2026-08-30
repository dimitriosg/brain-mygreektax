// Run with: npm test (from src/), or: node --test src/summary-parsing.test.js
//
// Node's built-in runner, so this adds no dependency to a bundle that ships to
// Lambda. Nothing in CI runs it: the deploy workflows only deploy.
//
// What is being protected: case_summaries.summary holds plain markdown, and a
// summary that could not be parsed used to be written to that column raw. Two
// of seventeen rows held a literal `{"summary": "## Case ...` string as a
// result, and one of them broke again on a later regenerate, so this is a
// recurring failure rather than a historical one.
//
// Fixtures are invented. Real summaries carry client names and AFMs, and R1
// keeps those out of the repo, so nothing here is copied from a stored row.

import assert from "node:assert/strict";
import test from "node:test";
import { extractSummaryText, stripCodeFence } from "./summary-parsing.js";

const MARKDOWN = "## Case summary\n\nClient is mid-filing.\n\n- E1 outstanding";
const ENVELOPE_SHAPE = /\{\s*"summary"\s*:/;

test("plain markdown is stored as written", () => {
    assert.equal(extractSummaryText(MARKDOWN), MARKDOWN);
});

test("a JSON envelope yields the summary, not the envelope", () => {
    assert.equal(extractSummaryText(JSON.stringify({ summary: MARKDOWN })), MARKDOWN);
});

test("a fenced JSON envelope yields the summary", () => {
    const raw = "```json\n" + JSON.stringify({ summary: MARKDOWN }) + "\n```";
    assert.equal(extractSummaryText(raw), MARKDOWN);
});

test("fenced markdown keeps its markdown, fence removed", () => {
    assert.equal(extractSummaryText("```markdown\n" + MARKDOWN + "\n```"), MARKDOWN);
    assert.equal(extractSummaryText("```\n" + MARKDOWN + "\n```"), MARKDOWN);
});

test("a complete envelope survives trailing chatter after it", () => {
    // Regression: slicing to the last brace, rather than demanding the text end
    // at the envelope, is what keeps a usable summary usable here.
    const envelope = JSON.stringify({ summary: MARKDOWN });
    assert.equal(extractSummaryText(envelope + "\n\nLet me know if you want more."), MARKDOWN);
    assert.equal(
        extractSummaryText("```json\n" + envelope + "\n```\n\nHappy to expand any section."),
        MARKDOWN,
    );
});

test("trailing chatter containing braces does not swallow a good envelope", () => {
    // Ending at the last brace in the response rather than at the close of the
    // first object failed this, and prose about a payload is exactly the kind
    // of trailing note that carries braces.
    const raw =
        JSON.stringify({ summary: MARKDOWN }) +
        '\n\nNote: the portal payload uses `{"case_id": "..."}`';
    assert.equal(extractSummaryText(raw), MARKDOWN);

    // A second complete object after the envelope, rather than braces inside
    // prose. The first one is the summary and the scan must stop there.
    const twoObjects =
        JSON.stringify({ summary: MARKDOWN }) +
        "\nExample: " +
        JSON.stringify({ next: "confirm with partner" });
    assert.equal(extractSummaryText(twoObjects), MARKDOWN);
});

test("braces inside the summary string do not end the envelope early", () => {
    // The scan has to ignore braces inside JSON strings, and an escaped quote
    // inside one must not be read as closing it.
    const tricky = '## Case summary\n\nAADE rejected `{"afm": "000000000"}` and the reply said "no".';
    assert.equal(extractSummaryText(JSON.stringify({ summary: tricky })), tricky);
});

test("a truncated envelope throws rather than being stored raw", () => {
    // The real failure: maxTokens cuts the envelope mid-string, so it cannot
    // parse. Storing this is what produced the unreadable rows.
    const truncated = '{"summary": "## Case summary\\n\\nClient is mid-fil';
    assert.throws(() => extractSummaryText(truncated), /does not parse/);
});

test("a summary that quotes an envelope is never replaced by the fragment", () => {
    // Why only a LEADING brace counts as an envelope. Unwrapping one found
    // further into the text swaps a real summary for the snippet it quotes,
    // and no preamble test separates the two: this one is short, has no
    // heading or list marker, and is an entirely ordinary thing to write.
    const quotingInProse =
        'The prior generation returned {"summary":"stale fragment"} after the AADE ' +
        "rejection. Regenerate after the client uploads the receipt.";
    assert.throws(() => extractSummaryText(quotingInProse), /Refusing to store it/);

    const quotingInMarkdown =
        '## Case summary\n\n- The stored value was {"summary": "stale fragment"} which broke the tab.';
    assert.throws(() => extractSummaryText(quotingInMarkdown), /Refusing to store it/);
});

test("a complete envelope behind a lead-in is refused, not unwrapped", () => {
    // The cost of the rule above: a usable envelope introduced by prose is
    // thrown away. That is a 500 and a regenerate with the previous summary
    // intact, which is the cheaper of the two mistakes.
    const raw = "Here is the requested summary:\n\n" + JSON.stringify({ summary: MARKDOWN });
    assert.throws(() => extractSummaryText(raw), /Refusing to store it/);
});

test("a wrong-shaped object is still refused, never stored as markdown", () => {
    // The reason the leading-brace trigger survives alongside the shape match.
    assert.throws(() => extractSummaryText('{"draft": "wrong shape"}'), /no usable summary/);

    // And the same object introduced by a line of prose. ENVELOPE_SHAPE does
    // not match it, because its first key is not "summary", so without the
    // ends-with-an-object check this whole response was stored verbatim.
    assert.throws(
        () => extractSummaryText('Here is the requested result:\n\n{"draft":"wrong shape"}'),
        /introduced by prose/,
    );
});

test("a summary that merely mentions JSON is still markdown", () => {
    // The other side of the ends-with-an-object check. What separates these
    // from the case above is that the response continues after the object,
    // which is what a summary quoting a payload looks like and what model
    // output terminating in JSON does not.
    const mentions = [
        '## Case summary\n\nThe payload was `{"afm": "000000000"}` which AADE rejected.',
        'AADE returned {"error":"invalid"} twice, so the filing is still open.',
        "## Case summary\n\n- Awaiting the receipt\n- Refile once it arrives",
    ];
    for (const text of mentions) {
        assert.equal(extractSummaryText(text), text);
    }
});

test("a truncated envelope behind a preamble also throws", () => {
    // The gap that mattered: keying off the first character alone let this one
    // through, because the text starts with "H" rather than "{".
    const raw = 'Here is the internal case summary:\n{"summary": "## Case summary\\n\\nClient is';
    assert.throws(() => extractSummaryText(raw), /Refusing to store it/);
});

test("an envelope with no summary field throws", () => {
    assert.throws(() => extractSummaryText('{"draft": "wrong shape"}'), /no usable summary/);
});

test("a summary field that is not a string is refused, never coerced", () => {
    // Coercion here is the corruption. {"summary": {...}} stringifies to the
    // literal "[object Object]", which is truthy, non-empty, not envelope
    // shaped, and would have been written straight over a working summary.
    const notStrings = [
        { summary: { text: "## Case summary" } },
        { summary: ["## Case summary", "- E1 outstanding"] },
        { summary: 12345 },
        { summary: true },
        { summary: null },
    ];
    for (const envelope of notStrings) {
        assert.throws(
            () => extractSummaryText(JSON.stringify(envelope)),
            /no usable summary string/,
            `coerced instead of refusing: ${JSON.stringify(envelope)}`,
        );
    }
});

test("an empty response throws", () => {
    for (const empty of ["", "   ", "```json\n```", null, undefined]) {
        assert.throws(() => extractSummaryText(empty), /empty summary/);
    }
});

test("markdown containing braces is not mistaken for an envelope", () => {
    // A summary may quote JSON or use braces in prose. It must survive intact.
    const withBraces =
        '## Case summary\n\nThe payload was `{"afm": "000000000"}` which AADE rejected.';
    assert.equal(extractSummaryText(withBraces), withBraces);
});

test("no return value is ever still envelope shaped", () => {
    // The invariant the stored rows violated. Anything that would break it is
    // refused rather than returned, whichever branch produced it.
    const corpus = [
        MARKDOWN,
        JSON.stringify({ summary: MARKDOWN }),
        "```json\n" + JSON.stringify({ summary: MARKDOWN }) + "\n```",
        '{"summary": "## Case summary\\n\\nClient is mid-fil',
        'Here is the summary:\n{"summary": "## Case summary\\n\\nClient',
        '## Case summary\n\nThe payload was `{"afm": "000000000"}`.',
        "```\n" + MARKDOWN + "\n```",
    ];
    for (const raw of corpus) {
        let out;
        try {
            out = extractSummaryText(raw);
        } catch {
            continue; // Refused, which is the safe outcome.
        }
        assert.ok(!ENVELOPE_SHAPE.test(out), `envelope shape survived for: ${raw.slice(0, 40)}`);
    }
});

test("stripCodeFence handles the fence shapes the model actually emits", () => {
    assert.equal(stripCodeFence(MARKDOWN), MARKDOWN, "unfenced text is left alone");
    // A whole fence on one line: the opening line is content, not a tag.
    assert.equal(stripCodeFence('```{"summary": "x"}```'), '{"summary": "x"}');
    // An inner fence inside a fenced summary survives, because the closer is
    // the last marker rather than the first.
    const withInner = "## Case summary\n\n```\nAFM 000000000\n```\n\n- E1 outstanding";
    assert.equal(stripCodeFence("```markdown\n" + withInner + "\n```"), withInner);
    // An unterminated fence still yields its content rather than the marker.
    assert.equal(stripCodeFence("```markdown\n" + MARKDOWN), MARKDOWN);
});
