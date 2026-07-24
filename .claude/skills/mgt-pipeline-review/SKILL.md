---
name: mgt-pipeline-review
description: Runs a cross case sweep of the MyGreekTax pipeline, surfacing what is stalled, what is past cadence, who owes what, and what is blocked on the accountant partner. Use whenever asked for a pipeline review, a weekly review, a state of play, "where is everything", "what is outstanding", "what am I waiting on", "what is blocked", or any request to look across all open cases rather than work a single one. Use it also when asked to prioritise the week or decide what to work on next, since that question cannot be answered case by case.
---

# Pipeline review

A synthesis pass across every open case. Not a dashboard, not a report for anyone else. The output is a working list that tells Jim what to do next and what is quietly rotting.

At current volume this is a skill rather than a tool because the interesting signal is cross case: the same partner blocking four things, the same rule recurring on new cases, three quotes all waiting on the same unconfirmed appendix line. None of that is visible from inside a single case file.

## Input

Read the case brain files. If they are stale or missing, say so plainly and review what exists rather than reconstructing from memory. A review built on remembered state is worse than a short review built on written state, because it reads as authoritative and is not.

Where a case has no brain file, list it as unfiled rather than skipping it. The gap is itself a finding.

## Structure

Produce these sections in this order. The order matters, because it runs from things that decay if untouched to things that merely need scheduling.

### 1. Money at risk

Cases where payment is expected and has not arrived, or where work is complete and the balance is uncollected. Deposits outstanding on issued quotes. Anything where partner cost has been or is about to be incurred against an unconfirmed client payment.

This is first because it is the only section where delay costs cash directly.

### 2. Owed to the client

Cases where the client is waiting on us, including cases where we are waiting on the partner. A client who paid and heard nothing does not distinguish between our delay and the partner's, and should not have to.

For each, state how long they have been waiting and what they were last told.

### 3. Owed by the partner

Every open confirmation sitting with Chrysostomos, grouped so that a single message can clear several at once. Note how long each has been outstanding.

Look for the batching opportunity explicitly. Several open questions to the same partner should travel together rather than as separate messages, and questions that have been waiting for a new case to justify them should be checked against the current pipeline to see whether that case has now arrived.

### 4. Cadence due

Cases returning SEND, OVERDUE or PARK from the follow up cadence skill. Do not restate the calculation, just the verdicts and the decisions they need.

Park candidates go here and must be visible. A review that never parks anything is not a review.

### 5. Stalled

Cases that are technically active but have not moved. Distinguish blocked (waiting on something identified, with an owner) from drifting (no identified blocker, just no movement). Drifting cases are the ones that need a decision, and they are the ones easiest to skip past.

### 6. Patterns worth capturing

Anything recurring across cases that is not yet written down anywhere: a rule that has now bitten more than once, a service that has been quoted case by case often enough to deserve a standing line, a client question that keeps arriving.

Propose these as knowledge candidates. Never promote anything to canonical or standing status directly. Promotion is Jim's alone, and the value of the review is surfacing the candidate, not deciding it.

### 7. This week

Three to five actions, ordered, each with an owner. Not a summary of the above. A choice about what actually gets done, which means leaving things out.

## Calibration

Be honest about drift. The purpose of the review is to surface what is being avoided, and a review that reports everything as fine has failed at its only job. If a case has not moved in three weeks and there is no blocker, say that plainly rather than describing it as ongoing.

Equally, do not manufacture urgency to make the review feel substantial. Some weeks the answer is that two things need doing and the rest is genuinely waiting.

Keep it scannable. This gets read on a phone. Short lines, no long prose blocks, no restating case history that Jim already holds.

## Rules that still bind

Wholesale figures and margins stay internal. The review is an internal document, so figures may appear, but nothing from it is ever forwarded to a client or a partner without stripping the money in the wrong direction.

Do not advance any case as part of the review. Stage changes go through the stage gate skill with their entry conditions checked. The review identifies candidates for movement, it does not move them.

Case identifiers: use the ID already on the case. Three formats are currently live and the reconciliation is unresolved, so never mint a new one or normalise an existing one silently.

## Worked example

Input: "Give me a review before I start the week."

Output shape:

```
MONEY AT RISK
- <case>: deposit quoted <date>, not received, <n> working days
- <case>: delivered, balance uncollected since <date>

OWED TO CLIENT
- <case>: paid <date>, last told <what>, waiting <n> days on partner

OWED BY PARTNER
- Chrysostomos, <n> open items, oldest <date>. Batchable into one message:
  <list>

CADENCE DUE
- <case>: SEND
- <case>: PARK candidate, needs a decision

STALLED
- <case>: blocked on <what>, owner <who>
- <case>: drifting, no blocker, no movement since <date>

PATTERNS
- <recurring thing>, seen on <n> cases, candidate for a standing line

THIS WEEK
1. ...
```

Fill only the sections that have content. An empty section is deleted, not padded.
