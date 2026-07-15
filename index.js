import { BedrockRuntimeClient, ConverseCommand } from "@aws-sdk/client-bedrock-runtime";
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const bedrock = new BedrockRuntimeClient({ region: "eu-north-1" });

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
        const sender = record?.sender;

        if (sender === 'ai_agent') {
            console.log("Safety Break: Aborting execution because the event sender is 'ai_agent'.");
            return { statusCode: 200, body: JSON.stringify({ message: "Loop prevented" }) };
        }

        if (!caseId) {
            return { statusCode: 400, body: JSON.stringify({ error: "Missing case_id parameter" }) };
        }

        console.log(`Processing orchestration sequence for Case ID: ${caseId}`);

        // Fetch chronological timeline entries
        const { data: timeline, error: dbError } = await supabase
            .from('case_timeline')
            .select('*')
            .eq('case_id', caseId)
            .order('created_at', { ascending: true });

        if (dbError) throw dbError;

        let formattedTimeline = "### Persistent Case Timeline\n\n";
        timeline.forEach(entry => {
            const rawPayload = entry.payload;
            const messageText = typeof rawPayload === 'object' ? (rawPayload.text || JSON.stringify(rawPayload)) : rawPayload;
            formattedTimeline += `**[${entry.sender.toUpperCase()} - ${entry.event_type}]:**\n${messageText}\n\n---\n\n`;
        });

        // REFACTORED SYSTEM PROMPT: Demanding a strict structural JSON output layout
        const systemPrompt = `You are the MyGreekTax Brain orchestrator. Review the persistent timeline history and analyze the tax context. 
        You must return your output ONLY as a valid JSON object matching this schema layout. Do not include markdown formatting like \`\`\`json blocks outside the text.

        {
          "proposed_draft": "Your client-ready professional email text response here using appropriate spacing and markdown newlines.",
          "internal_notes": "Your private executive technical tax notes, compliance alerts, missing data points, and risk warnings for the internal operations team here."
        }`;

        console.log("Invoking serverless model endpoint...");

        const command = new ConverseCommand({
            modelId: "eu.anthropic.claude-sonnet-4-6",
            messages: [{ role: "user", content: [{ text: formattedTimeline }] }],
            system: [{ text: systemPrompt }],
            inferenceConfig: {
                maxTokens: 4000,
                temperature: 0.1 // Lowered temperature to enforce strict JSON syntax tracking
            }
        });

        const response = await bedrock.send(command);
        
        let aiRawText = "";
        if (response.output?.message?.content?.[0]?.text) {
            aiRawText = response.output.message.content[0].text;
        } else {
            throw new Error("No textual parameters returned from Bedrock service.");
        }

        console.log("Raw Text Output received from AI:", aiRawText);

        // Clean up any loose wrapper fragments the AI might have accidentally appended
        const cleanJsonString = aiRawText.substring(aiRawText.indexOf("{"), aiRawText.lastIndexOf("}") + 1);
        const structuredOutput = JSON.parse(cleanJsonString);

        console.log("Successfully parsed AI output into JSON variables.");

        // 1. Log the structured action history back onto the main case timeline
        await supabase.from('case_timeline').insert({
            case_id: caseId,
            event_type: 'ai_draft_suggested',
            sender: 'ai_agent',
            payload: { 
                text: structuredOutput.proposed_draft,
                notes: structuredOutput.internal_notes
            }
        });

        // 2. UPSERT the latest values straight into your review desk tracking layer
        // This ensures your "Pending Approvals View" always displays the most updated draft version
        const { error: upsertError } = await supabase
            .from('case_drafts')
            .upsert({
                case_id: caseId,
                proposed_draft: structuredOutput.proposed_draft,
                internal_notes: structuredOutput.internal_notes,
                is_approved: false,
                last_updated: new Date().toISOString()
            }, { onConflict: 'case_id' }); // Overwrites the existing open draft for this case

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
