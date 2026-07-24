---
name: kb-entry
description: Write, review and promote MyGreekTax knowledge entries, both the wiki pages in this repo and the knowledge_base rows injected into Brain drafting. Use this skill whenever a page under wiki/ is created or edited, a tax rule is encoded from research or from a partner answer, a page is being considered for promotion from DRAFT to CANONICAL, an entry needs re-verification, or a wiki page is being turned into a knowledge_base row. Trigger it before writing any tax fact intended to persist, because anything that reaches canonical is quoted to clients as settled and the citation discipline is the only thing standing between research and a wrong filing.
---

# Knowledge entries

The same knowledge lives in two homes, and they have different shapes.

**`wiki/` in this repo** is the working knowledge base: markdown pages with a `Status:` header, reviewed and promoted by hand. Format is defined by `wiki/rules/_TEMPLATE_rule.md`. Use that template, do not invent a different one.

**`knowledge_base` in Supabase** is what the Brain actually reads. The Lambda injects a row only when all three hold: `status = 'canonical'`, `is_active = true`, `visibility = 'client_safe'`. A wiki page that has not been turned into a row is not doing anything for drafting.

The rules governing both already live in `CLAUDE.md` in this repo: R1 for PII, R2 for the pricing firewall, R3 for what needs partner confirmation, R4 for sources and canonical status, R5 for style. This skill does not restate them. It carries the mechanics.

## The gate

**Only Δημήτρης promotes.** Pages and rows are born DRAFT. A draft row is not injected, which is the fail closed default and is deliberate. Nothing produced by an ingest, a research pass or this skill arrives canonical. If asked to write something directly as canonical, write it as draft and say why.

**The Brain never writes to `knowledge_base`.** Proposed learnings go to `knowledge_candidates` with status `pending`, and rows there are never read into any prompt. Promotion means creating a `knowledge_base` row from an approved candidate, by hand.

## Writing a wiki page

Copy `wiki/rules/_TEMPLATE_rule.md`. The header block is not decorative:

- `Status:` DRAFT on creation, always.
- `Last reviewed:` the date the sources were actually opened, not the date the file was touched.
- `Affects services:` which service lines this changes. This is what makes the page findable when a case comes in.

Then, in the body:

- **Sources are mandatory and specific.** An AADE page with URL and access date, a law or circular (ΠΟΛ or Ε number), a treaty article, or a dated partner confirmation in the form `per [partner], YYYY-MM-DD`. A source that is a summary of a source is not a source.
- **One claim per paragraph**, as the template says. It makes the page correctable a claim at a time rather than a rewrite at a time.
- **Say what is unverified, inline.** `tax-residency-transfer.md` does this well: it separates confirmed operational knowledge from the OECD general framework it has not yet sourced to Greek primary material, and stays DRAFT because of it. Copy that habit.
- **Deadlines get a hedge.** Greek deadlines are extended late in the season more often than not, so the page says to verify live status on AADE or myAADE rather than asserting a date. Label anything year specific as tax year and filing year both.
- **Limits and exceptions earn their own section.** The Article 5C limitation, that it covers Greek source income only and expires after seven tax years, is the sort of thing omitted from third party analyses, and it reverses the answer for a DNV holder.

## Turning a page into a knowledge_base row

Field mapping, wiki to row:

| Wiki page | knowledge_base column |
|---|---|
| filename without `.md` | `slug` |
| `# Heading` | `title` |
| directory (`rules/`, `sops/`) | `category` |
| `Status: DRAFT` or `CANONICAL` | `status` (`draft` / `canonical`) |
| `Last reviewed:` plus a horizon | `review_by` |
| Sources section, condensed | `source` |
| body | `content` |
| judgement call, see below | `visibility` |

`visibility` is `client_safe` only when every sentence could be shown to a client exactly as written. Anything with operational detail, partner names, internal policy or process is `internal_only`. `sops/enarxi-requirement.md` is canonical and is squarely `internal_only`, since it is about partner onboarding and names the legal entity.

**Slugs are permanent.** `knowledge_base.slug` is unique and seeding uses `on conflict (slug) do nothing`. A rename does not rename: the next seed run inserts a second copy under the old slug, and every citation pointing at it breaks. Retire an entry with `is_active = false`. Supersede it with a new slug and deactivate the old one. Never rename.

Use `assets/kb-row-template.md` when writing a row directly rather than promoting a page.

## What never goes in

No client PII in `wiki/`, `cases/` or `pricing/`, per R1. No pricing anywhere in `wiki/`, per R2: figures live only in `pricing/price-table.md`, and an entry that reaches drafting is where a stray figure becomes a quote. No partner pipeline assessments, competitor notes or strategy. No em dashes or en dashes.

No claim sourced only to an AI generated document. Research output, including from research tools and from previous Claude sessions, is unverified by default and cross checks against primary sources before it becomes a page. A wrong entry that reaches canonical is repeated confidently to every client the rule touches, which is the failure this whole structure exists to prevent.

## Checking

```bash
python .claude/skills/kb-entry/scripts/check_entry.py wiki/rules/tax-residency-transfer.md
python .claude/skills/kb-entry/scripts/check_entry.py wiki/
```

It reads both formats, the repo's `Status:` header block and YAML front matter for rows, and validates the field set, slug format, source presence and shape, review staleness, and the prohibitions above. It cannot judge whether the tax content is correct. That is the partner's job, and R3 lists what always needs partner confirmation before it is stated to a client as final.

## Promotion path

1. Page exists as DRAFT, or a `pending` row sits in `knowledge_candidates`.
2. Run the checker. Fix everything it reports.
3. Verify each claim against its cited primary source, one at a time. Cross checking a citation means opening it, not recognising it.
4. Route anything on the R3 list to the partner and wait. Record the answer as `per [partner], YYYY-MM-DD`.
5. Δημήτρης promotes: `Status: CANONICAL` on the page, `status = 'canonical'` on the row. Update `wiki/index.md`, which is the ledger of what is canonical and what is draft.
6. When a canonical entry is later contradicted by a newer source or a partner correction, update it immediately and note the change and date in the changelog at the bottom.
