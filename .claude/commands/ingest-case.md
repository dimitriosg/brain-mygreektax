---
description: Anonymize a closed case and compound its lessons into the brain
---

Ingest a case into the brain. Input: $ARGUMENTS. If no input is given, read the files currently in `inbox/`.

Follow CLAUDE.md rules strictly, especially R1 (no PII in permanent files).

Steps:

1. Read the raw material (email thread, notes, documents).
2. Extract the facts of the case: who the client is by situation only (nationality, residency status, income types, family situation), which services were involved, what questions arose, how they were resolved, and what the partner corrected or confirmed.
3. Assign the next case ID by checking `cases/index.md` (format: MGT-2026-NNN).
4. Write the case file at `cases/MGT-2026-NNN.md` using `cases/_TEMPLATE_case.md`. Anonymize fully. No names, no AFMs, no contact details, no dates of birth. Partner names are allowed.
5. Identify anything REUSABLE: a rule clarification, a process step, a treaty interpretation, a phrase that worked well with a client. For each, either update the matching page in `wiki/` or create a new one. All new or changed wiki content is born with `Status: DRAFT`.
6. Update `cases/index.md` with one line: ID, date, type, services, one-sentence pattern.
7. Output a short summary for Δημήτρης: what was stored, what wiki pages were created or changed and now await promotion, and a reminder to delete the raw source from `inbox/` if it contains PII.

Never skip step 7. Never promote anything to CANONICAL yourself.
