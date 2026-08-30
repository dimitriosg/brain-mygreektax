// Reading the model's summary response, as pure string handling.
//
// Separate from index.js so it can be tested without pulling in the Bedrock
// and Supabase clients: nothing here talks to anything.

export function asText(value) {
    if (typeof value === "string") return value.trim();
    if (value === null || value === undefined) return "";
    return String(value).trim();
}

/** Drop a leading ```json (or ```markdown, or bare ```) fence and its closer. */
export function stripCodeFence(text) {
    if (!text.startsWith("```")) return text;
    return text
        .replace(/^```[^\n]*\n?/, "")
        .replace(/\n?```\s*$/, "")
        .trim();
}

/**
 * The summary to store, from whatever the model actually returned.
 *
 * case_summaries.summary holds plain markdown. The model is asked for exactly
 * that, but it sometimes answers with the JSON envelope the drafting path uses
 * instead, sometimes inside a fence. Unwrapping that is the easy half.
 *
 * The half that matters is what happens when unwrapping fails. This used to
 * fall back to storing the raw response, so a response that would not parse
 * was written to the column verbatim: rows holding a literal
 * `{"summary": "## Case ...` with escaped newlines, which the Summary tab then
 * renders faithfully and unreadably. maxTokens is 2000, so a long case can
 * truncate the envelope mid-string and fail to parse for a summary that was
 * otherwise fine, which is why one case broke, was regenerated, and broke the
 * same way.
 *
 * So the rule is asymmetric on purpose. Text that is not envelope-shaped is
 * taken as the markdown it claims to be. Text that IS envelope-shaped must
 * parse and yield a summary, or this throws and nothing is written: the
 * previous summary staying put is worth more than a fresh one nobody can read.
 */
export function extractSummaryText(rawText) {
    const text = stripCodeFence(asText(rawText));
    if (!text) {
        throw new Error("Model returned an empty summary.");
    }

    if (text.startsWith("{")) {
        let parsed;
        try {
            parsed = JSON.parse(text);
        } catch (parseError) {
            throw new Error(
                `Model returned a JSON summary envelope that does not parse (${parseError.message}). ` +
                    "Refusing to store it; the previous summary is left unchanged.",
            );
        }
        const summary = asText(parsed?.summary);
        if (!summary) {
            throw new Error(
                "Model returned a JSON object with no usable summary field. " +
                    "Refusing to store it; the previous summary is left unchanged.",
            );
        }
        return summary;
    }

    // Not envelope-shaped. A markdown summary can legitimately contain braces,
    // so an embedded object counts as an envelope only if it actually parses
    // AND carries a summary. Anything else is the markdown it looks like.
    const firstBrace = text.indexOf("{");
    const lastBrace = text.lastIndexOf("}");
    if (firstBrace !== -1 && lastBrace > firstBrace) {
        try {
            const embedded = JSON.parse(text.slice(firstBrace, lastBrace + 1));
            const summary = asText(embedded?.summary);
            if (summary) return summary;
        } catch {
            // Braces in prose, not an envelope. Keep the text as written.
        }
    }

    return text;
}
