---
name: mgt-followup-cadence
description: Decides whether a MyGreekTax case or lead should get a follow up now, wait, or be parked, and drafts the follow up when one is due. Use whenever asked to chase, nudge, follow up, check in on, or bump a client, lead or partner, whenever asked "have I heard back from X" or "what should I chase today", whenever a case has gone quiet, and whenever reviewing which open threads still deserve attention. Use it even when the request is phrased as simple drafting ("write Sigrid a nudge"), because whether to send at all is the actual decision and sending too early or too often is the failure mode.
---

# Follow up cadence

The rule is one follow up, five to seven working days after the last outbound contact, then stop.

The reason it needs enforcing rather than remembering: open threads accumulate at different ages, and the natural instinct is to chase the ones that feel most valuable rather than the ones that are actually due. That produces early nudges on warm leads and permanent silence on cold ones, which is backwards. A lead that has not answered after one properly timed follow up has answered.

## Run the calculator first

Do not count working days by hand. Greek public holidays are movable and the spring cluster shifts with Orthodox Easter, so a manual count is wrong often enough to matter.

```bash
python scripts/cadence.py --last-outbound YYYY-MM-DD [--followups-sent N] [--today YYYY-MM-DD]
```

It returns one of four verdicts:

| Verdict | Meaning | Action |
|---|---|---|
| WAIT | Window has not opened | Hold. Report the date it opens. Do not draft. |
| SEND | Inside the 5 to 7 day window | Draft the single follow up. |
| OVERDUE | Past the window, none sent | Send now and accept the delay, or park directly if cold. |
| PARK | One already sent | Cadence exhausted. Draft the closing note instead. |

If the last outbound date is unknown, ask for it rather than estimating. An estimate here produces a real send at a wrong time.

## The park decision carries the value

Parking is what stops the open list growing, and it is the half of this skill most likely to be skipped. Treat PARK and OVERDUE-gone-cold as real outputs, not as failures to be worked around.

A parked case is not lost. It is a case that no longer consumes attention, with the door left open. The closing note should acknowledge cleanly, name any material deadline risk they should know about, and stop. No pressure, no final pitch, no "just checking one more time".

Signals that OVERDUE should become PARK rather than a late send:

- The deadline the enquiry was built around has passed
- They have said they are comparing quotes and gone quiet, which usually means they chose
- The enquiry was a weak signal lead to begin with
- More than roughly fifteen working days have elapsed

## What a follow up actually is

One short message. It adds something rather than merely repeating that a message was sent. Useful additions, in rough order of strength:

- A deadline that has moved closer since the last contact, stated factually
- A relevant change in the rules or the process
- A narrowing of the ask, for example dropping from three outstanding questions to the single one that actually blocks the quote
- An explicit and pressure free exit: it is completely fine if the timing is wrong

What it is not: a restatement of the quote, a discount, a new offer, or a request for a decision by a date we invented. Never manufacture urgency. Real deadlines only, and only where they genuinely apply to that client.

Length: shorter than the message it follows.

## Stage interaction

The stage gate skill governs what may be sent at each stage, and that still binds here. A follow up on a Quoted case cannot carry a document checklist or methodology, however tempting it is to add value that way. If the follow up feels thin because the useful content is gated, that is the gate working correctly. Send the thin version.

A follow up never advances a stage by itself. If the reply moves the case, that is a stage gate decision.

## Partner follow ups differ

Chrysostomos is not a lead and the cadence is not a sales cadence. Where a case is blocked on a partner answer, the follow up is a status check, not a nudge, and email remains the channel for anything substantive with WhatsApp for quick chases only. Register and language rules belong to the partner comms skill.

The one rule that does carry across: a blocked case still needs an owner. If a partner answer has not arrived and the client is waiting, the client is owed an update even when there is nothing to report. Silence toward a paying client while waiting on a partner is the worst position in the pipeline.

## Output format

```
CASE: <id or name>
LAST OUTBOUND: <date>
VERDICT: <WAIT | SEND | OVERDUE | PARK>  (<n> working days elapsed)
REASONING: <one line, including the park or send call where it is a judgment>
```

Then the draft, if one is due. No draft on WAIT.

When run across several cases at once, list every case with its verdict first, then draft only for the ones that need sending. Do not bury a PARK inside prose. It should be as visible as a SEND.

## Worked examples

**Example 1.**
Input: "Anything I should chase today?"
Output: run the calculator for each open case, present the verdict list, draft only the ones returning SEND. Name the PARK candidates explicitly and ask for a decision on each, since parking is Jim's call rather than an automatic action.

**Example 2.**
Input: "Sigrid still has not replied, over three weeks now. Send her another one."
Output: calculator returns OVERDUE or PARK depending on whether a follow up already went out. If one did, the cadence is exhausted, so draft the closing note rather than a second chase. Say why. A second follow up after three weeks of silence converts a soft no into a hard one and costs the relationship the option of them returning later.

**Example 3.**
Input: "Client paid the deposit last week and I have not heard from Chrysostomos. What do I do?"
Output: two separate actions. The partner side gets a status check. The client side gets a proactive update even though there is nothing to report, because they have paid and are waiting. Do not let the partner delay become client silence.
