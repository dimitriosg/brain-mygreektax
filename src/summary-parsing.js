// Reading the model's summary response, as pure string handling.
//
// Separate from index.js so it can be tested without pulling in the Bedrock
// and Supabase clients: nothing here talks to anything. Both deploy workflows
// package this file alongside index.js; if you add another module here, add it
// to the zip line in .github/workflows/deploy.yml and deploy-staging.yml too,
// because that list is explicit and a missing file breaks every invocation.

/**
 * A value as trimmed display text, coercing whatever it is given.
 *
 * Used across the timeline formatters, where a number or a null in a database
 * column should read as text rather than crash the prompt. Coercion is the
 * point here, which is exactly why the summary field does not go through it:
 * see summaryFromEnvelope.
 */
export function asText(value) {
    if (typeof value === "string") return value.trim();
    if (value === null || value === undefined) return "";
    return String(value).trim();
}

// A JSON object that opens with a "summary" key. This is the shape that was
// landing in case_summaries.summary verbatim, and the shape no return value
// from extractSummaryText may ever have.
const ENVELOPE_SHAPE = /\{\s*"summary"\s*:/;

/**
 * The content of a leading code fence, fence markers removed.
 *
 * Returns the text unchanged when it does not start with a fence. When it
 * does, everything up to the last closing fence is the content, so trailing
 * chatter after the block ("Let me know if you want more detail") is dropped
 * rather than left to defeat the closing marker. An inner fence inside a
 * fenced markdown summary survives, because the last marker is the closer.
 */
export function stripCodeFence(text) {
    if (!text.startsWith("```")) return text;

    const afterTicks = text.slice(3);
    const newline = afterTicks.indexOf("\n");
    const firstLine = newline === -1 ? afterTicks : afterTicks.slice(0, newline);

    // A language tag is a bare word. Anything else on that first line is
    // content, which is how a whole fence written on one line arrives.
    const firstLineIsLanguageTag = newline !== -1 && /^[a-zA-Z0-9_+-]*$/.test(firstLine.trim());
    const body = firstLineIsLanguageTag ? afterTicks.slice(newline + 1) : afterTicks;

    const closer = body.lastIndexOf("```");
    return (closer === -1 ? body : body.slice(0, closer)).trim();
}

/**
 * The summary to store, from whatever the model actually returned.
 *
 * case_summaries.summary holds plain markdown, and SUMMARY_SYSTEM_PROMPT now
 * asks for exactly that. It used to ask for {"summary": "..."} instead, which
 * is the whole reason this function exists: maxTokens is 2000, so a long case
 * truncated the envelope mid-string, JSON.parse failed, and the raw text was
 * stored as a fallback. Two rows ended up holding a literal
 * `{"summary": "## Case ...` with escaped newlines, and one of them broke the
 * same way again after a regenerate.
 *
 * With the prompt asking for markdown, truncation now costs the tail of a
 * readable summary instead of the whole thing. An envelope arriving anyway is
 * treated as a deviation and handled, because the model was trained on the old
 * instruction and stored rows predate the change.
 *
 * The rule is asymmetric on purpose. Text that is not envelope-shaped is taken
 * as the markdown it claims to be. Text that IS envelope-shaped must parse and
 * yield a summary, or this throws and nothing is written: the previous summary
 * staying put is worth more than a fresh one nobody can read.
 *
 * The last guard is the one that matters. Whatever path produced the result,
 * it may not still look like an envelope. That refuses a summary whose own
 * prose quotes `{"summary":`, which is possible but not something a case
 * summary does, and the cost of that refusal is a regenerate rather than a
 * corrupted column.
 */
export function extractSummaryText(rawText) {
    const text = stripCodeFence(asText(rawText));
    if (!text) {
        throw new Error("Model returned an empty summary.");
    }

    const envelopeAt = envelopeStart(text);
    const result = envelopeAt === -1 ? text : summaryFromEnvelope(text.slice(envelopeAt));

    if (ENVELOPE_SHAPE.test(result)) {
        throw new Error(
            "Model returned a JSON summary envelope that could not be unwrapped " +
                "(most likely truncated by maxTokens). Refusing to store it; the " +
                "previous summary is left unchanged.",
        );
    }
    return result;
}

/**
 * Where the envelope starts in the response, or -1 if it is not one.
 *
 * Only a response that OPENS with a brace counts, and it counts whatever it
 * contains, so a wrong-shaped object like {"draft": "..."} is refused
 * downstream rather than stored as if it were markdown.
 *
 * An envelope behind a lead-in ("Here is the requested summary:") is
 * deliberately not unwrapped, and this position was reached by trying the
 * alternative and finding it unsafe. Nothing distinguishes the model
 * introducing its answer from a summary mentioning a stored value, because a
 * real summary can be short and unstructured and still quote one:
 *
 *   The prior generation returned {"summary":"stale fragment"} after the AADE
 *   rejection. Regenerate after the client uploads the receipt.
 *
 * Unwrapping that returns "stale fragment" and destroys the summary. Refusing
 * a prose-prefixed envelope costs a 500 and a regenerate, with the previous
 * summary intact; guessing costs the summary itself. The asymmetry decides it.
 */
function envelopeStart(text) {
    return text.startsWith("{") ? 0 : -1;
}

/**
 * The index of the brace closing the object that starts at position 0, or -1
 * if it never closes.
 *
 * Counting braces is not enough on its own, because a summary is prose and
 * prose contains braces. They have to be ignored inside JSON strings, and an
 * escaped quote inside such a string must not be read as ending it.
 */
function firstObjectEnd(text) {
    let depth = 0;
    let inString = false;
    let escaped = false;

    for (let i = 0; i < text.length; i += 1) {
        const char = text[i];

        if (inString) {
            if (escaped) escaped = false;
            else if (char === "\\") escaped = true;
            else if (char === '"') inString = false;
            continue;
        }

        if (char === '"') inString = true;
        else if (char === "{") depth += 1;
        else if (char === "}") {
            depth -= 1;
            if (depth === 0) return i;
        }
    }

    return -1;
}

/**
 * The summary carried by a response that opens with a JSON object.
 *
 * Throws rather than returning anything it could not read cleanly, because the
 * caller writes the result over an existing summary and a bad write is worse
 * than no write.
 */
function summaryFromEnvelope(text) {
    // End at the close of the first complete object rather than the last brace
    // in the response. Trailing chatter after a good envelope may itself
    // contain braces, and taking the last one swallows it and fails a summary
    // that was perfectly usable. A -1 here means the object never closed,
    // which is what truncation looks like, and JSON.parse reports it.
    const objectEnd = firstObjectEnd(text);
    let parsed;
    try {
        parsed = JSON.parse(objectEnd === -1 ? text : text.slice(0, objectEnd + 1));
    } catch (parseError) {
        throw new Error(
            `Model returned a JSON summary envelope that does not parse (${parseError.message}). ` +
                "Refusing to store it; the previous summary is left unchanged.",
        );
    }

    // Deliberately not asText() here. That coerces, and coercing this field is
    // how {"summary": {...}} becomes the literal string "[object Object]"
    // written over a summary that was fine. A summary is text or it is nothing.
    const summary = typeof parsed?.summary === "string" ? parsed.summary.trim() : "";
    if (!summary) {
        const found = parsed?.summary === undefined ? "absent" : typeof parsed.summary;
        throw new Error(
            `Model returned a JSON object with no usable summary string (summary was ${found}). ` +
                "Refusing to store it; the previous summary is left unchanged.",
        );
    }
    return summary;
}
