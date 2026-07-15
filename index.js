import { BedrockRuntimeClient, ConverseCommand } from "@aws-sdk/client-bedrock-runtime";
import { createClient } from '@supabase/supabase-js';

const authHeader = event.headers['x-api-secret'] || event.headers['X-Api-Secret'];
if (authHeader !== process.env.WEBHOOK_SECRET) {
    return { statusCode: 401, body: JSON.stringify({ error: "Unauthorized access" }) };
}

// Initialize external clients outside the handler to leverage AWS container reuse
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const bedrock = new BedrockRuntimeClient({ region: "eu-north-1" });

export const handler = async (event) => {
    try {
        // 1. Extract case information from the incoming trigger event
        const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
        const caseId = body?.case_id;

        if (!caseId) {
            return { statusCode: 400, body: JSON.stringify({ error: "Missing case_id parameter" }) };
        }

        // 2. Reconstruct the persistent timeline directly from Supabase
        const { data: timeline, error } = await supabase
            .from('case_timeline')
            .select('*')
            .eq('case_id', caseId)
            .order('created_at', { ascending: true });

        if (error) throw error;

        // 3. Compile chronological events into a structured markdown stream matching your repo's style
        let formattedTimeline = "### Persistent Case Timeline\n\n";
        timeline.forEach(entry => {
            formattedTimeline += `**[${entry.sender.toUpperCase()} - ${entry.event_type}]:**\n${entry.payload.text}\n\n---\n\n`;
        });

        // 4. Construct systemic instructions aligned with your brand guidelines
        const systemPrompt = "You are the MyGreekTax Brain orchestrator. Review this persistent timeline history, analyze the context, and draft the next required response. Separate outputs strictly into [READY TO SEND] and [INTERNAL NOTES].";
        const userPrompt = `Analyze this timeline and generate the target draft:\n\n${formattedTimeline}`;

        // 5. Invoke the Serverless Engine using the optimized Converse API
        const command = new ConverseCommand({
            modelId: "eu.anthropic.claude-3-5-sonnet-20241022-v2:0", // Fast EU-routed cross inference
            messages: [{ role: "user", content: [{ text: userPrompt }] }],
            system: [{ text: systemPrompt }]
        });

        const response = await bedrock.send(command);
        const aiOutput = response.output.message.content[0].text;

        // 6. Write the resulting draft entry back into your database timeline
        await supabase.from('case_timeline').insert({
            case_id: caseId,
            event_type: 'ai_draft_suggested',
            sender: 'ai_agent',
            payload: { text: aiOutput }
        });

        return {
            statusCode: 200,
            body: JSON.stringify({ status: "Brain orchestration complete", response: aiOutput })
        };

    } catch (err) {
        console.error("Execution error:", err);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: "Internal Brain processing failed", details: err.message })
        };
    }
};
