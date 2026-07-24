---
name: mgt-stage-gate
description: Governs the MyGreekTax case pipeline (Potential, Quoted, Active, Delivered, Complete, Parked) by checking whether a case may move to the next stage and what artifact that move requires. Use this whenever a new lead or enquiry arrives, whenever asked to move, advance, progress, close or park a case, whenever asked whether to send a quote, request a deposit, assign work to Chrysostomos, request the balance, or deliver, and whenever a message contains an unqualified lead that needs triage. Use it even when the request sounds like a simple drafting task ("reply to this lead", "send the ανάθεση", "write the checklist for X"), because those actions are stage transitions in disguise and the deposit gate has to be checked before any of them.
---

# MyGreekTax stage gate

The pipeline has six stages. This skill decides whether a case may move, and refuses the move when the entry condition is not met.

The reason this exists: four separate operating rules all collapse onto one transition. No methodology before deposit, no document checklists before deposit, no partner assignment before deposit, and partner costs never fronted before client payment lands. Those are not four rules. They are one gate, stated four times, on the Quoted to Active edge. Enforcing the gate structurally means none of the four can be forgotten individually.

## Before anything: unresolved configuration

Two decisions are open. Do not guess them. If a task depends on one, say which, and ask.

**Stage ownership.** `resolve_case_for_inbound()` in Supabase already carries a `stage` column via `brain_conversations_identity_link`. The six stage framework was separately planned against Airtable. Until Jim confirms which is authoritative, report a stage change as a recommendation and name the system it needs writing to. Never assume the write happened.

**Case ID format.** Three formats are live: `MGT-2026-NNN` (repo case template), `MGT-CS001-CLT0033` and `UK-AC-26` (working cases), and the `MGT-CSxxx-CLTxxxx` serial returned by `resolve_case_for_inbound()`. Never mint a new ID. Use the ID already on the case. If a new case needs one, ask which format applies.

## The six stages

| Stage | Meaning |
|---|---|
| Potential | Enquiry received, not yet priceable |
| Quoted | Written quote issued, awaiting acceptance and deposit |
| Active | Deposit confirmed, work under way |
| Delivered | Work complete, balance requested |
| Complete | Balance collected, case closed |
| Parked | Cadence exhausted, declined, or client self handling |

## Transitions

Each edge has an entry condition that must be true before the move, and an exit artifact the move produces. No artifact means the move has not happened.

### Potential to Quoted

Entry condition: scope is clear enough to price, meaning either the service maps to a confirmed line, or the quote unlocking questions have been answered.

Read `references/triage.md` before working any Potential stage case. It covers commitment signal reading, the minimum questions that unlock a quote, and when a lead should go straight to Parked instead.

Exit artifact: a written quote with scope, fee, and payment structure.

Blocked when: the service is κατά περίπτωση and Chrysostomos has not priced it, or the appendix status for that line is unconfirmed. Say so rather than quoting anyway.

### Quoted to Active

**This is the gate.** Entry condition: client deposit confirmed received. Not promised, not invoiced, not "they said yes". Confirmed, with a payment reference.

Everything below is forbidden while the case sits in Quoted:

- Document checklists sent to the client
- Methodology or procedural explanation of how the work will be done
- Locked figures beyond the quote itself
- Any ανάθεση, scoping request or assignment to Chrysostomos
- Any partner cost incurred on the case

Permitted while in Quoted: scope clarification, the minimum questions needed to unlock or firm up the quote, payment logistics, and answering what a service is without explaining how it is executed.

If asked to produce any forbidden item on a Quoted case, do not produce it. Name the gate, state what is outstanding, and offer the permitted alternative. This holds even when the client sounds ready, even when there is deadline pressure, and even when the request comes from Jim rather than the client. Deadline pressure is the exact circumstance the rule exists for.

Exit artifact: payment confirmation logged to the case file, then the ανάθεση to Chrysostomos.

Sequencing within the transition matters. Deposit lands first, then the case file is updated, then the partner assignment goes out. An ανάθεση sent before the deposit is the failure mode this gate prevents.

### Active to Delivered

Entry condition: the work product exists and has passed its own quality checks. For an E1 that means the pre submission cross checks have been run and the residency position is correct. Never treat a draft assessment showing unexpected tax due as a green light.

Exit artifact: the deliverable, plus the balance request.

Blocked when: scope has expanded beyond the quote. Article 5A, 5B, 5C or DNV angles surfacing mid engagement mean pause and re scope in writing, do not proceed on the original quote. A scope expansion sends the case back to Quoted for the new portion, with its own deposit gate. It does not ride along on the original deposit.

### Delivered to Complete

Entry condition: balance collected.

Exit artifact: case file closed with outcome recorded, portal tracker moved, open confirmations either cleared or migrated to whoever still owns them. Any reusable pattern proposed for the knowledge base as a candidate, never promoted directly.

### Any stage to Parked

Entry condition: one of, the follow up cadence is exhausted, the client has declined, the client has chosen to self handle, or the case is blocked on something outside our control with no live date.

Exit artifact: a clean closing note that acknowledges without pressure, states any material deadline risk they should know about, and leaves the door open.

Parked is a real stage, not a failure. On a competitor quote situation, hold the original price, do not counter, do not discount, park cleanly.

## Money direction rule

Wholesale figures, margins and partner rates never appear in client facing text. Retail figures, client fee totals and markup logic never appear in partner facing text. Both directions apply at every stage.

The full pricing rule lives with the quote builder skill once it exists. Until then, treat the prohibition above as absolute and defer any actual figure selection to Jim.

## Output format

When asked to advance a case, respond in this shape:

```
STAGE: <current> to <proposed>
GATE: PASS or BLOCKED
<if blocked: what is outstanding, and who owes it>
REQUIRED ARTIFACT: <what this move must produce>
WRITE TO: <Supabase or Airtable, flagged as unresolved if it is>
NEXT ACTION: <the single next thing, and whose it is>
```

Then produce the artifact itself if the gate passed, or the permitted alternative if it did not.

Keep the block short. It is a check, not a report.

## Worked examples

**Example 1.**
Input: "Dominik replied and he is ready to go. Draft him the document checklist so he can get started."
Output: gate BLOCKED. Quote issued, deposit not confirmed. A document checklist is forbidden pre deposit. Offer instead: a short reply confirming the scope and sending the payment link, with the checklist held until the deposit lands. State plainly that the checklist follows immediately on payment, so the client does not read the sequencing as friction.

**Example 2.**
Input: "New enquiry from a Lithuanian freelancer thinking about moving in 2027. What do I send?"
Output: Potential stage. Read `references/triage.md`. Weak commitment signal, distant date, so holding pattern rather than full engagement. Send the minimum quote unlocking questions only. No pricing, no methodology. Flag internally as low priority with a review date.

**Example 3.**
Input: "Deposit came in on the back filing case, send Chrysostomos the ανάθεση."
Output: gate PASS if the payment reference is on file. Confirm the reference, update the case file first, then produce the ανάθεση in formal Greek with the case code rather than the client name, no attachments, no retail figures. Note that partner comms has its own skill and register rules.

**Example 4.**
Input: "This client is going to miss the deadline, just send the partner the assignment and we will collect after."
Output: gate BLOCKED, and the pressure is the reason not the exception. Partner costs are never fronted. Offer the fastest permitted path instead: payment link with a same day turnaround note, and an honest statement of what is still achievable if payment lands today.

## Related skills

Triage detail sits in `references/triage.md`. Follow up timing belongs to the follow up cadence skill. Cross case sweeps belong to the pipeline review skill. Drafting the artifacts themselves belongs to house style for clients and partner comms for Chrysostomos. This skill decides whether the artifact may be produced at all.
