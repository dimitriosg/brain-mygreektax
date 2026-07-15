import { BedrockRuntimeClient, ConverseCommand } from "@aws-sdk/client-bedrock-runtime";
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const bedrock = new BedrockRuntimeClient({ region: "eu-north-1" });

const record = body?.record || body;
const caseId = record?.case_id;
const sender = record?.sender; // <--- Get the sender

// SAFETY BREAK: If the AI generated this row, STOP immediately to prevent infinite loops!
if (sender === 'ai_agent') {
    console.log("Safety Break: Aborting execution because the event sender is 'ai_agent'.");
    return { statusCode: 200, body: JSON.stringify({ message: "Loop prevented" }) };
}

export const handler = async (event) => {
    console.log("Raw API Gateway Event Received:", JSON.stringify(event));

    try {
        let body;
        if (typeof event.body === 'string') {
            body = JSON.parse(event.body);
        } else {
            body = event.body;
        }

        const record = body?.record || body;
        const caseId = record?.case_id;

        if (!caseId) {
            console.error("Validation failed. Missing case_id inside record object:", JSON.stringify(body));
            return { statusCode: 400, body: JSON.stringify({ error: "Missing case_id parameter" }) };
        }

        console.log(`Processing orchestration sequence for Case ID: ${caseId}`);

        const { data: timeline, error: dbError } = await supabase
            .from('case_timeline')
            .select('*')
            .eq('case_id', caseId)
            .order('created_at', { ascending: true });

        if (dbError) {
            console.error("Supabase Database fetch operation failed:", dbError);
            throw dbError;
        }

        let formattedTimeline = "### Persistent Case Timeline\n\n";
        timeline.forEach(entry => {
            const rawPayload = entry.payload;
            const messageText = typeof rawPayload === 'object' ? (rawPayload.text || JSON.stringify(rawPayload)) : rawPayload;
            formattedTimeline += `**[${entry.sender.toUpperCase()} - ${entry.event_type}]:**\n${messageText}\n\n---\n\n`;
        });

        console.log("Assembled Timeline context payload for Bedrock Engine:\n", formattedTimeline);

        const systemPrompt = "You are the MyGreekTax Brain orchestrator. Review this persistent timeline history, analyze the context, and draft the next required response. Separate outputs strictly into [READY TO SEND] and [INTERNAL NOTES].";
        
        console.log("Invoking serverless model endpoint...");

        // Updated with the correct system routing identifier
        const command = new ConverseCommand({
            modelId: "eu.anthropic.claude-sonnet-4-6",
            messages: [{ role: "user", content: [{ text: formattedTimeline }] }],
            system: [{ text: systemPrompt }]
        });

        const response = await bedrock.send(command);
        const aiOutput = response.output.message.content.text;
        
        console.log("AI Response successfully compiled:", aiOutput);

        console.log("Writing response entry back to Supabase...");
        // Fixed: Explicitly wrapping the string output as a JSON object
        const { error: insertError } = await supabase
            .from('case_timeline')
            .insert({
                case_id: caseId,
                event_type: 'ai_draft_suggested',
                sender: 'ai_agent',
                payload: { text: aiOutput } // Ensure it's nested under the 'text' key
            });


        if (insertError) {
            console.error("Failed to append AI agent row back to Supabase:", insertError);
            throw insertError;
        }

        console.log("Orchestration pipeline execution successful.");
        return { statusCode: 200, body: JSON.stringify({ status: "Success" }) };

    } catch (err) {
        console.error("Critical Brain pipeline runtime crash:", err.message);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: "Internal processing crash", details: err.message })
        };
    }
};
