# MyGreekTax Brain: Starter Kit (Phase 1)

A local, git-versioned knowledge base that behaves like your senior case handler: it compounds lessons from every case, drafts client and partner emails under your rules, and preps you for calls. It prepares; the licensed OEE partner confirms and executes. Phase 1 is manual ingest. Phase 2 (auto-feed from Supabase) comes after the conversation loggers are confirmed end to end.

## What is in the box

```
mygreektax-brain/
├── CLAUDE.md                  the constitution: role, three layers, hard rules R1 to R6
├── .claude/commands/          three slash commands for Claude Code
│   ├── ingest-case.md         /ingest-case
│   ├── draft-reply.md         /draft-reply
│   └── prep-call.md           /prep-call
├── wiki/                      permanent knowledge (anonymized, sourced, statused)
│   ├── index.md               home page and canonical/draft ledger
│   ├── rules/                 tax rules; tax-residency-transfer.md is your first build target
│   ├── sops/                  έναρξη requirement + εξουσιοδότηση workflow (canonical seeds)
│   ├── services.md            catalog WITHOUT prices (safe to quote anywhere)
│   └── style/                 your email voice, both languages
├── cases/                     anonymized case patterns, the muscle memory
├── pricing/                   RESTRICTED: retail + wholesale + margin, firewall rules inside
├── inbox/                     temporary drop zone for raw material, gitignored, cleared after ingest
└── raw/                       source documents (laws, AADE pages), gitignored by default
```

## Setup (10 minutes)

Requirements: Node.js 24+, git, and Claude Code (included in the Claude Pro plan, or pay-as-you-go with your existing Anthropic API key; note that if ANTHROPIC_API_KEY is set in your shell, Claude Code bills the API instead of your subscription).

1. Unzip this folder somewhere permanent, e.g. `~/mygreektax-brain`
2. `cd mygreektax-brain && git init && git add . && git commit -m "brain: phase 1"`
3. Install Claude Code if you have not: `npm install -g @anthropic-ai/claude-code`
4. Run `claude` inside the folder. It reads CLAUDE.md automatically and the three commands appear as `/ingest-case`, `/draft-reply`, `/prep-call`.

Optional, for the visual wiki browser: `npm install -g @inkeep/open-knowledge`, then `ok init` inside this folder (if it generates its own CLAUDE.md, keep yours and append theirs below it), then `ok start --open`.

## The daily loop

- A case closes: drop the thread or your notes into `inbox/`, run `/ingest-case`, review what it proposes, say "promote" for what is correct, delete the raw file.
- An email needs answering: paste the thread into the chat and run `/draft-reply` with who it is for and the goal. You get [READY TO SEND] plus [INTERNAL NOTES].
- A call is coming: run `/prep-call` with the person and purpose, paste the recent thread. You get a one-page brief.

Client PII flows through sessions and `inbox/` only. It is never written into `wiki/`, `cases/`, or `pricing/`, and `inbox/` plus `raw/` are gitignored so nothing sensitive enters git history.

## First week, in order

1. Open `pricing/price-table.md`: verify the retail column against the live site, fill the wholesale columns from the agreed and pending Παράρτημα Α rates. This unlocks margin-aware quoting.
2. Ingest your first two cases: one real client case and the Stefania pilot as a partner case. This validates the anonymization flow and starts the ledger.
3. Build `wiki/rules/tax-residency-transfer.md` from primary sources (the page lists which). Verify with the partner, promote to canonical. This simultaneously becomes the research base for your cornerstone article.

## Weekly maintenance (10 minutes)

Open `wiki/index.md`, review the draft list, promote or correct. If the brain needs more hand-holding than this after two weeks of real use, tell it what went wrong in CLAUDE.md terms and tighten the rules there, not in your head.

## Phase 2 (do not build yet)

Trigger: outbound logger (6289248) confirmed end to end and inbound (6289179) upgraded. Then: a small export script pulls new rows from the Supabase `messages` table into `inbox/` as markdown, and `/ingest-case` runs on a weekly batch instead of manual drops. The brain then feeds itself from infrastructure you already built. Nothing else changes: same rules, same firewall, same promotion flow.
