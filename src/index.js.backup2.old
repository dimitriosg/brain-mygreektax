import { BedrockRuntimeClient, ConverseCommand } from "@aws-sdk/client-bedrock-runtime";
import { createClient } from "@supabase/supabase-js";

const bedrock = new BedrockRuntimeClient({ region: "eu-north-1" });

// Lazy client creation: a missing environment variable produces a clean
// error response instead of an initialization crash on every invoke.
let cachedSupabase;
function getSupabase() {
    if (cachedSupabase) return { client: cachedSupabase };
    const url = process.env.SUPABASE_URL;
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!url || !key) {
        return { configError: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in Lambda environment variables." };
    }
    cachedSupabase = createClient(url, key);
    return { client: cachedSupabase };
}

const SYSTEM_PROMPT = `You are the MyGreekTax Brain orchestrator. MyGreekTax is an English-language coordination service for expats dealing with Greek tax matters. All regulated filings are executed by licensed Greek accountant partners; MyGreekTax itself is the coordination and communication layer, not an accounting firm.

Review the persistent case timeline and produce two outputs.

Rules for proposed_draft (the client-facing email):
1. Write in clear, warm, plain English addressed to the client.
2. Never state deadlines, monetary amounts, legal provisions, or filing requirements as fact unless they appear explicitly in the timeline. If the client needs such information and it is not in the timeline, say it will be confirmed and list it in internal_notes as an item to verify with the accountant partner.
3. Never use em dashes or en dashes anywhere. Use commas, colons, or parentheses instead.
4. Do not write any sign-off, closing salutation, or signature at the end of the email. End the message after its last substantive sentence. A signature block is appended automatically after your draft; adding your own would duplicate it.
5. Do not mention prices unless a price already appears in the timeline.
6. Do not present MyGreekTax as an accountant or law firm.

Rules for internal_notes (private operations notes):
1. Flag every claim in the draft that requires verification by the licensed partner before sending.
2. Note compliance risks, missing documents, and open questions.
3. Never use em dashes or en dashes.

You must return ONLY a valid JSON object matching this schema, with no markdown fences and no text outside the object:

{
  "proposed_draft": "client-ready email text",
  "internal_notes": "private operations notes"
}`;

export const handler = async (event) => {
    console.log("Raw API Gateway Event Received:", JSON.stringify(event));

    try {
        // Optional shared secret. Enforced only when BRAIN_WEBHOOK_SECRET is
        // set on the Lambda. Add the matching x-brain-secret header in the
        // Supabase Database Webhook configuration.
        const expectedSecret = process.env.BRAIN_WEBHOOK_SECRET;
        if (expectedSecret) {
            const provided = event.headers?.["x-brain-secret"] || event.headers?.["X-Brain-Secret"];
            if (provided !== expectedSecret) {
                console.warn("Rejected request: missing or wrong x-brain-secret header.");
                return { statusCode: 401, body: JSON.stringify({ error: "Unauthorized" }) };
            }
        }

        let body;
        try {
            body = typeof event.body === "string" ? JSON.parse(event.body) : event.body;
        } catch {
            return { statusCode: 400, body: JSON.stringify({ error: "Invalid JSON body" }) };
        }

        const record = body?.record || body;
        const caseId = record?.case_id;
        const sender = record?.sender;
        const caseSerialId = record?.case_serial_id ?? null;

        const NON_TRIGGERING_SENDERS = new Set(["ai_agent", "internal"]);
        if (NON_TRIGGERING_SENDERS.has(sender)) {
            console.log(`Safety Break: sender '${sender}' does not trigger drafting.`);
            return { statusCode: 200, body: JSON.stringify({ message: "Loop prevented" }) };
        }

        if (!caseId) {
            return { statusCode: 400, body: JSON.stringify({ error: "Missing case_id parameter" }) };
        }

        const supabaseResult = getSupabase();
        if (supabaseResult.configError) {
            console.error(supabaseResult.configError);
            return { statusCode: 500, body: JSON.stringify({ error: supabaseResult.configError }) };
        }
        const supabase = supabaseResult.client;

        console.log(`Processing orchestration sequence for Case ID: ${caseId}`);

        const { data: timeline, error: dbError } = await supabase
            .from("case_timeline")
            .select("*")
            .eq("case_id", caseId)
            .order("created_at", { ascending: true });

        if (dbError) throw dbError;

        let formattedTimeline = "### Persistent Case Timeline\n\n";
        timeline.forEach((entry) => {
            const senderLabel = (entry.sender || "unknown").toUpperCase();
            const eventLabel = entry.event_type || "event";
            const rawPayload = entry.payload;
            const messageText =
                typeof rawPayload === "object" && rawPayload !== null
                    ? rawPayload.text || JSON.stringify(rawPayload)
                    : rawPayload;
            formattedTimeline += `**[${senderLabel} | ${eventLabel}]:**\n${messageText}\n\n***\n\n`;
        });

        console.log("Invoking serverless model endpoint...");

        const command = new ConverseCommand({
            modelId: "eu.anthropic.claude-sonnet-4-6",
            messages: [{ role: "user", content: [{ text: formattedTimeline }] }],
            system: [{ text: SYSTEM_PROMPT }],
            inferenceConfig: {
                maxTokens: 4000,
                temperature: 0.1,
            },
        });

        const response = await bedrock.send(command);

        let aiRawText = "";
        if (response.output?.message?.content?.[0]?.text) {
            aiRawText = response.output.message.content[0].text;
        } else {
            throw new Error("No textual parameters returned from Bedrock service.");
        }

        console.log("Raw Text Output received from AI:", aiRawText);

        // Parse the structured output. If the model returned something that is
        // not valid JSON, do not crash after already paying for the call:
        // store the raw text as the draft and flag it for manual review.
        let structuredOutput;
        try {
            const cleanJsonString = aiRawText.substring(aiRawText.indexOf("{"), aiRawText.lastIndexOf("}") + 1);
            structuredOutput = JSON.parse(cleanJsonString);
            if (typeof structuredOutput.proposed_draft !== "string") {
                throw new Error("proposed_draft missing from parsed output");
            }
        } catch (parseError) {
            console.error("AI output was not valid JSON, storing raw text for manual review:", parseError.message);
            structuredOutput = {
                proposed_draft: aiRawText,
                internal_notes: "AUTOMATIC FLAG: the AI response was not valid JSON. The raw output has been stored as the draft. Review carefully before any use.",
            };
        }

        console.log("Structured output ready.");

        // 1. Log the AI action back onto the case timeline. The database
        // webhook will fire once more for this row and the sender guard
        // above will stop the loop.
        await supabase.from("case_timeline").insert({
            case_id: caseId,
            case_serial_id: caseSerialId,
            event_type: "ai_draft_suggested",
            sender: "ai_agent",
            payload: {
                text: structuredOutput.proposed_draft,
                notes: structuredOutput.internal_notes,
            },
        });

        // 2. Upsert the latest draft into the review desk tracking table.
        const { error: upsertError } = await supabase
            .from("case_drafts")
            .upsert(
                {
                    case_id: caseId,
                    proposed_draft: structuredOutput.proposed_draft,
                    internal_notes: structuredOutput.internal_notes,
                    is_approved: false,
                    last_updated: new Date().toISOString(),
                },
                { onConflict: "case_id" },
            );

        if (upsertError) {
            console.error("Failed to update case_drafts review index table:", upsertError);
            throw upsertError;
        }

        console.log("Structured review database tables populated successfully.");
        return { statusCode: 200, body: JSON.stringify({ status: "Success" }) };
    } catch (err) {
        console.error("Critical Brain pipeline runtime crash:", err.message);
        return { statusCode: 500, body: JSON.stringify({ error: "Processing failed", details: err.message }) };
    }
};
