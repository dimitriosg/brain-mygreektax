# MyGreekTax Brain

The institutional memory and drafting engine of MyGreekTax, an English-language Greek tax coordination service for expats, digital nomads, and foreign property owners. The Brain analyses a case, drafts the client and partner communications under a fixed set of rules, and packages everything so the licensed OEE partner only needs to confirm and execute. It prepares; the partner is the licensed authority and confirms every live tax position before it reaches a client as fact.

MyGreekTax is never described as a licensed accounting or law firm. All regulated filings are executed by a licensed member of the Economic Chamber of Greece (OEE).

## What this repo actually is

Three things live together here, sharing one governance model:

1. **Operating rules and knowledge.** `CLAUDE.md` (the constitution) plus the `wiki/`, `cases/`, and `pricing/` folders. This is the human-readable, git-versioned knowledge that compounds over time.
2. **The agent layer.** `.claude/commands/` (typed slash commands for Claude Code) and `.claude/skills/` (model-invoked skills that govern the case pipeline). This is what turns the knowledge into actions.
3. **The deployed drafting service.** `src/` (an AWS Lambda plus a portal route), `supabase/migrations/` (the knowledge governance schema), and `.github/workflows/deploy.yml` (the deploy pipeline). This is the automated Brain behind the portal's Generate button.

The connective tissue: knowledge is authored and reviewed as markdown in `wiki/`, promoted from DRAFT to CANONICAL by hand, and the canonical facts live as governed rows in the Supabase `knowledge_base` table. The Lambda reads those governed rows at draft time. Same knowledge, two surfaces.

## Repository layout

```
brain-mygreektax/
├── CLAUDE.md                     constitution: role, three layers, hard rules R1 to R7
├── .claude/
│   ├── commands/                 Claude Code slash commands
│   │   ├── ingest-case.md        /ingest-case
│   │   ├── draft-reply.md        /draft-reply
│   │   └── prep-call.md          /prep-call
│   └── skills/                   model-invoked skills (portable across Claude Code, Desktop, claude.ai)
│       ├── mgt-stage-gate/       six-stage pipeline, enforces the deposit gate (R7)
│       ├── mgt-followup-cadence/ send / wait / park decision, working-day calculator
│       ├── mgt-pipeline-review/  cross-case sweep: stalled, overdue, blocked on partner
│       └── kb-entry/             write, review, and promote knowledge entries
├── wiki/                         permanent knowledge, anonymized and sourced
│   ├── index.md                  home page and canonical / draft ledger
│   ├── rules/                    tax rules (tax-residency-transfer.md is the lead page)
│   ├── sops/                     enarxi requirement, exousiodotisi workflow (both canonical)
│   ├── services.md               service catalog WITHOUT prices (safe to quote anywhere)
│   └── style/                    email voice, both languages
├── cases/                        anonymized case patterns, the muscle memory
├── pricing/                      RESTRICTED: retail, wholesale, margin. Firewall rules inside.
├── inbox/                        temporary drop zone for raw material (gitignored)
├── raw/                          source documents, laws, AADE pages (gitignored)
├── src/                          the deployed drafting service
│   ├── index.js                  AWS Lambda handler (Bedrock + Supabase)
│   ├── package.json              Lambda dependencies
│   └── routes/drafts.tsx         portal /drafts review inbox (TanStack Router)
├── supabase/migrations/          knowledge governance schema, seed, resolve_case_for_inbound()
├── .github/workflows/deploy.yml  push to main -> AWS Lambda
└── .env.example                  environment variable template
```

## The rules

The full constitution is in `CLAUDE.md` and is authoritative. In brief:

- **R1. No client PII in permanent files.** Names, AFMs, emails, phones, addresses, TAXISnet or myAADE credentials, IBANs never enter `wiki/`, `cases/`, or `pricing/`. Cases describe people by situation only. Partner names are allowed (they are business counterparties, not clients).
- **R2. Pricing firewall.** No retail price, margin, markup logic, or client fee total ever appears in any text addressed to a partner or accountant candidate. Partner-facing drafts get a final currency-figure scan. Use "κατόπιν συμφωνίας" or omit the figure.
- **R3. Verify-with-partner triggers.** Multi-country income, split-year residency, Article 5A, business structure, back-year penalties, EFKA, treaty (ΣΑΔΦ) interpretation, and imminent deadlines stay provisional in client wording until the partner confirms.
- **R4. Sources and status.** Every factual tax claim carries a source and a status line (CANONICAL or DRAFT). AI-generated syntheses are always born DRAFT. Only Δημήτρης promotes.
- **R5. Style.** Fixed signature, no em or en dashes in any output, formal plural for new Greek contacts, plain warm English for clients.
- **R6. Communication boundaries.** Never reference one partner to another, never imply exclusivity, one clear ask per message.
- **R7. Deposit gate.** No case moves from Quoted to Active until the client deposit is confirmed received with a payment reference. While Quoted, no checklists, no methodology, no partner assignment. Enforced by the `mgt-stage-gate` skill and holds under deadline pressure.

## Commands (Claude Code only)

Run these inside the folder with `claude`:

- `/ingest-case` : anonymize a closed case and compound its lessons into the Brain.
- `/draft-reply` : draft a client or partner email under all rules. Returns [READY TO SEND] plus [INTERNAL NOTES].
- `/prep-call` : produce a one-page call brief.

## Skills (model-invoked, portable)

Skills trigger on context rather than being typed, and the same folder works in Claude Code, Claude Desktop, and claude.ai. Where a command and a skill touch the same action, the skill decides whether the action is permitted and the command produces the artifact.

- **`mgt-stage-gate`** : governs the six-stage pipeline (Potential, Quoted, Active, Delivered, Complete, Parked) and enforces R7. Lead triage lives in its references.
- **`mgt-followup-cadence`** : decides send, wait, or park on a quiet thread. Ships a working-day calculator with Greek public holidays.
- **`mgt-pipeline-review`** : cross-case sweep. What is stalled, past cadence, owed, or blocked on the partner.
- **`kb-entry`** : write, review, and promote knowledge entries, both the wiki pages and the `knowledge_base` rows.

## The knowledge model

New knowledge enters as DRAFT, from an ingest, a research pass, or a partner answer. Δημήτρης reviews and says "promote" for a page to become CANONICAL. When a canonical page is contradicted by a newer source or a partner correction, it is updated immediately with the change and date noted at the bottom.

Canonical facts are mirrored into the Supabase `knowledge_base` table, which is the only thing the deployed Lambda reads. The Brain never writes to `knowledge_base` directly; promotion is always a supervised step.

## The deployed drafting service

`src/index.js` is an AWS Lambda named `mygreektax-brain` in `eu-north-1`. It:

- calls a Claude model via **AWS Bedrock** (`@aws-sdk/client-bedrock-runtime`, Converse API),
- reads governed `knowledge_base` entries and recent case learnings from Supabase (capped: 25 KB entries, 40k chars, 5 learnings),
- assembles a persistent case timeline, and
- returns a structured draft (proposed draft plus internal notes) for review.

`src/routes/drafts.tsx` is the portal's `/drafts` review inbox: it lists proposed drafts (case id, draft, internal notes, approval state, last updated) pulled from Supabase using the publishable key, so drafts are reviewed and approved before anything is sent.

`supabase/migrations/` holds the governance schema: `knowledge_governance`, the `knowledge_seed`, the `resolve_case_for_inbound()` identity function, and the knowledge layer.

### Deploy

Any push to `main` triggers `.github/workflows/deploy.yml`, which installs production dependencies, zips `src/`, and runs `aws lambda update-function-code` against the live function. There is no test gate and no staging step. A push to `main` is a production deploy. Treat it accordingly.

### Environment variables

The Lambda entry point reads `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` from its Lambda environment. `.env.example` additionally declares `ANTHROPIC_API_KEY`, `MAKE_TO_BRAIN_WEBHOOK_SECRET`, and `RESEND_API_KEY`; confirm which of these the current handler still uses and prune the rest. AWS credentials for deploy are GitHub Actions secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`), not committed. All `.env*` files except `.env.example` are gitignored.

## Local use (Claude Code or claude.ai)

Requirements: Node.js 22+ (the deploy pipeline uses Node 22), git, and Claude Code.

1. Clone the repo and run `claude` inside it. It reads `CLAUDE.md` automatically; the three commands appear as `/ingest-case`, `/draft-reply`, `/prep-call`, and the skills load on context.
2. Daily loop:
   - A case closes: drop the thread into `inbox/`, run `/ingest-case`, review, say "promote" for what is correct, delete the raw file.
   - An email needs answering: paste the thread, run `/draft-reply` with who it is for and the goal.
   - A call is coming: run `/prep-call` with the person and purpose.
3. Weekly maintenance (about ten minutes): open `wiki/index.md`, review the draft list, promote or correct.

## Data safety

Client PII flows through live sessions and `inbox/` only. It is never written into `wiki/`, `cases/`, or `pricing/`. `inbox/` and `raw/` are gitignored so nothing sensitive enters git history. The `pricing/` folder is restricted internal material and belongs only where it cannot be read by partners, candidates, or the public.

## Status and roadmap

The drafting service and knowledge governance schema are built and deployed. The markdown knowledge base is seeded: the SOP pages and the email style guide are canonical, and `wiki/rules/tax-residency-transfer.md` is a populated DRAFT awaiting primary-source ingest and partner sign-off on split-year treatment. The case ledger starts at `MGT-2026-001`.

Next: ingest the first real cases to start the ledger, complete the primary-source verification on the residency-transfer page and promote it, and reconcile the environment variable template against what the Lambda actually consumes.
