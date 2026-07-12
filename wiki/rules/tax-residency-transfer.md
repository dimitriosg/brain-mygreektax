# Tax residency transfer (inbound and outbound)

Status: DRAFT
Last reviewed: 2026-07-13
Affects services: Tax Residency Moving to Greece, Tax Residency Leaving Greece

Pricing for this service lives exclusively in `pricing/price-table.md` (rule R2, the firewall). This page never states a retail or wholesale figure, so it stays safe to pull from in any draft, including partner-facing ones.

## The rule

This section stays DRAFT until Greece-specific primary sources (AADE guidance, ΠΟΛ/Ε circulars, ΣΑΔΦ tie-breaker articles) are ingested and partner-verified. The operational content below is already confirmed working knowledge from the project, not a substitute for that source pass, and is flagged accordingly.

### General framework (OECD model, not yet Greece-specific-sourced)

Residency determinations generally rest on four tests: physical presence (183 days in the tax year), permanent home (available and accessible throughout the year), center of vital interests (family, business, and social ties, used as a tie-breaker), and habitual abode (a regular, continuous pattern that short absences don't break). These tests often conflict in a transition year: someone leaving Greece can still pass the 183-day test for the departure year while establishing residency elsewhere.

The OECD Model tie-breaker hierarchy, which most bilateral treaties follow when residency is contested: permanent home first, then habitual abode, then nationality, then mutual agreement between the two tax authorities if the above are inconclusive.

### AFM is not tax residency

Getting an AFM does not make someone a tax resident. AFM registration and tax residency registration are two separate processes, and this is a common point of client confusion worth addressing directly and early.

### Inbound: foreign to Greek tax residence

**Trigger.** Client has centre of vital interests in Greece, or has been physically present more than 183 days, but is still flagged as non-resident in AADE.

**Request name.** Μεταβολή φορολογικής κατοικίας (από εξωτερικό σε Ελλάδα)

**Submission channels.**
- myAADE, Τα Αιτήματά μου (preferred)
- Physical protocol to the competent ΔΟΥ Κατοίκων Εξωτερικού, when the myAADE path is blocked

**Document set.**
- myAADE-registered lease covering the relevant year
- Proof of presence and local ties: work contract, utility bills, transport tickets, school enrolment for dependants
- Foreign tax certificate if available, useful when the prior jurisdiction wants to keep the client on its books
- ID, passport, AFM

**After acceptance.** Client is filed as Greek tax resident for the relevant year onward. Worldwide income reporting applies, with foreign tax credit available where a treaty applies. Special regimes (the 50 percent expat exemption, Article 5A non-dom, Digital Nomad Visa) may apply and should trigger a re-scope.

**Operational rule: code 319.** If the client's draft E1 has code 319 ticked (the non-resident-filing-in-Greece checkbox) but the facts say they should be a Greek tax resident, do not submit. Hold the filing, run the residency-transfer request, wait for AADE acceptance, then untick 319 and re-run E1. A draft assessment showing tax due that would not apply under resident treatment is a flag, not a green light. This is confirmed operational practice, not yet tied to a specific circular citation.

**Sequencing rule.** Residency correction always precedes amended returns, which precede the current-year filing. Never file the current year before the registry is corrected.

**Code 319 misclassification, as a pattern.** This is not a one-off. It recurs, typically surfacing as an unexpectedly large balance due on a non-resident-flagged draft. Treat that combination (large balance due, code 319 ticked, facts suggesting residency) as the default hypothesis to check first.

### Outbound: Greek to foreign tax residence

**Trigger.** Client is leaving Greece permanently or has already left.

**Authorisation pattern for Portuguese and Spanish-speaking clients.** A scoped power of attorney, separate from the standard εξουσιοδότηση used for filing, authorising MyGreekTax and the accountant partner to act exclusively in matters related to changing fiscal residence and fiscal exit from Greece before AADE, the competent ΔΟΥ, myAADE, and other competent bodies. Grants powers to submit applications, declarations, notifications, and clarifications, to deposit and receive documents and certificates, to respond to clarification requests, to monitor progress, and to perform necessary procedural steps. Must state explicitly that it applies only to the stated case, not to unrelated general tax matters.

**Audience note.** A meaningful share of the client base is Portuguese and Spanish-speaking (LATAM to Greece, and EU to Greece). Templates should exist in both languages plus Greek, not English-only.

**Templates pending.** Spanish (WhatsApp and formal email), Portuguese, and Greek (Υπεύθυνη Δήλωση) versions exist in prior working material but are not yet consolidated here. Build as a separate templates-pack deliverable.

### Split-year treatment

Not yet documented for Greek practice specifically. General concept: a taxpayer is treated as resident for part of the year and non-resident for the remainder, requiring a clearly documented transfer date and evidence of intent (change of address, school enrolment, employment contract, housing lease). Some treaties allow it explicitly; Greece's acceptance in practice is unconfirmed and requires partner input.

**Partner input required before this subsection can leave DRAFT.** Standing question for Chrysostomos: does AADE genuinely pre-approve split-year for inbound transfers in practice, what is the process, and what is the typical rejection reason.

### Article 5C interaction (flagged, not yet a residency-transfer rule in its own right)

The 5C regime (50 percent relocation and remote-worker exemption) does not apply to clients whose income is foreign-sourced only, such as UK rental income or digital nomad income earned abroad. It applies only to clients with Greek employment or business income who also hold qualifying foreign income. A 2025 benefit claim is not automatically lost on early exit, but AADE may examine genuine intent. This matters directly for outbound cases where a client with an active 5C claim is now transferring residency out. Anything touching 5A, 5B, or 5C is κατά περίπτωση and routes to Chrysostomos for scoping before a quote.

### Case complexity taxonomy

This is the granularity both the finished rule file and any future client-facing article should be structured around; it is already the shape the business prices against (see `pricing/price-table.md` for the wholesale figures that map to each line):

- Αλλαγή φορολογικής κατοικίας προς Ελλάδα, απλή περίπτωση (single origin country, clear ΣΑΔΦ, mainly salaried)
- Αλλαγή προς Ελλάδα, μεσαία πολυπλοκότητα (foreign income, dividends, dual-year coverage)
- Αλλαγή προς Ελλάδα, σύνθετη (multiple jurisdictions, business owner, or Article 5A prep)
- Αλλαγή από Ελλάδα προς εξωτερικό, απλή
- Αλλαγή από Ελλάδα προς εξωτερικό, σύνθετη
- Πιστοποιητικό Φορολογικής Κατοικίας (standalone certificate, no full transfer)
- Άρθρο 5Α (non-dom regime), application and support
- Άρθρο 5Β (pensioners), application and support

### Premium deliverable: the written residency position report

Beyond the standard transfer service, the highest-value residency deliverable on record is a fixed-scope written residency position report: a formal document arguing that a client remains (or becomes) a tax resident of a specific jurisdiction under the applicable ΣΑΔΦ treaty, citing the relevant AADE circular, the treaty tie-breaker article, and any applicable administrative exemption (for example an illness-related exemption from the day-count). It is preceded by a paid consultation to lock the facts before drafting. This suits high-stakes cases: large families, five-figure double-tax exposure, or a contested residency position where the client needs something defensible in writing rather than a form filing. It is a distinct scope from a transfer and should be quoted as such. Pricing is in pricing/price-table.md.

### Adjacent deadline facts (E1, not residency-specific, but sequencing-relevant)

Verified June 2026 from AADE and Greek press, reconfirm before publishing anything with dates in it:
- E1 filing deadline for tax year 2025: 15 July 2026 (31 July for individuals participating in legal entities with single-entry books).
- First tax payment, or the single lump-sum, due 31 July 2026, payable in up to 8 monthly instalments.
- Single-payment discount tiers of 4 percent, 3 percent, and 2 percent depending on filing date, with the 2 percent tier applying to returns filed by 15 July.

## Sources

No residency-specific ΠΟΛ/Ε circular or ΣΑΔΦ tie-breaker text has been ingested yet. What follows is general AADE and reform-tracking material, not residency-transfer-specific, plus the research checklist for the pass that still needs to run.

**Already have (general, not residency-specific):**
- AADE official E1/E2/E3 guidance: https://www.aade.gr/en/personal-income-tax-return-e1-e2-e3
- AADE separate-filing notification: https://www.aade.gr/gnostopoiisi-horistis-dilosis
- gov.gr filing portal entry: https://www.gov.gr/en/arxes/anexartete-arkhe-demosion-esodon-aade/anexartete-arkhe-demosion-esodon-aade/delose-phorologias-eisodematos-php-e1-e2-e3
- Greek personal income tax brackets: Law 4172/2013, codified by Law 4799/2021
- Law 5246/2025 reforms (2026 income, forward planning only): Greek Ministry of Economy and Finance guide (minfin.gov.gr); KPMG Greece tax update 20/11/2025; Bernitsas Law and Mondaq alerts; PwC Worldwide Tax Summaries (Greece); OECD Taxing Wages 2026. Verified June 2026.
- OECD Model Tax Convention: general tie-breaker framework cited above, not a Greece-specific source and not a substitute for the actual ΣΑΔΦ text per country.

**Still to ingest, in priority order:**

1. **Forms.** M0 (Δήλωση Μεταβολής Στοιχείων Φυσικού Προσώπου, the change-of-status form, including the residency field and the 15-day submission window), M1 (annual return, how a mid-year residency change is declared and whether a split-year election field exists), M7 (outbound notification to ΔΟΥ Κατοίκων Εξωτερικού).
2. **Circulars (ΠΟΛ).** The current circular on μεταβολή φορολογικής κατοικίας, including the exact resident-status definition and required documentation. A separate circular on accepted 183-day proof: passport stamps versus electronic records, and whether employer or school letters count as supporting evidence.
3. **Rulings (Ε).** Recent AADE rulings on residency transfers, split-year acceptances or rejections, and common documentation deficiencies.
4. **ΔΟΥ Κατοίκων Εξωτερικού procedure.** How the Register of Foreign Residents actually updates after an M7 submission, and what triggers automatic notification versus a manual chase.
5. **Treaty text by country**, extracting the residency article and any split-year or relief provision, for: United Kingdom (2013 convention or later amendment, Article 4), United States (Article 4, and note that state-level residency can complicate this separately from the federal treaty), Germany, Netherlands, Australia. Source: OECD Treaty Portal or the Greek Ministry of Finance treaty database.
6. **183-day documentation standards.** The AADE-accepted evidence chain: passport stamps, Schengen visa stickers, travel records, employer payroll records, school enrolment, utility bills, bank statements, rental agreement or deed, car registration, health insurance. And separately: when a standalone Βεβαίωση Φορολογικής Κατοικίας is required, which ΔΟΥ issues it, processing time, and validity period.

## Partner verification required

Items that need Chrysostomos's direct input, not just published guidance, before the corresponding subsections above can leave DRAFT:

- Whether AADE genuinely pre-approves split-year elections for inbound transfers, and what the practical process and rejection reasons look like.
- M7 processing time for outbound changes, and whether AADE proactively notifies ΔΟΥ Κατοίκων Εξωτερικού or this requires manual follow-up.
- How strictly 183-day documentation is reviewed in practice, and what gets commonly rejected.
- Post-departure audit horizon: how long AADE typically continues to examine an outbound case, and what triggers a residency challenge.
- Form-level guidance: which fields on M0/M1/M7 most often cause a follow-up request.

## Edge cases seen in practice

Cases below are anonymized by situation only. No names, no contact details, no case-identifying specifics beyond what illustrates the pattern. These should also be formally ingested via `/ingest-case` to get proper case IDs in `cases/index.md`; they are captured here as rule-relevant patterns in the meantime.

**Inbound, complex, multi-jurisdiction (illustrative anchor case).** Client had a nomadic period across several countries before landing in Greece, plus wire transfers from a third country, a second nationality's passport registration, two employers, and worldwide income with foreign tax credit implications. AADE had the client on record as a foreign tax resident with a foreign address, while a Greek employer was simultaneously reporting salary under the client's AFM, a mismatch that surfaces later as an AADE cross-check or notice. Correct sequence was residency change first, then E1; filing E1 first would have produced the wrong assessment. This remains the clearest proof point on file that the flagship tier is doing real diagnostic work, not just form-filling. Initial consultation and AADE status checks were done at no charge, including in this instance where the client ultimately did not proceed to the paid engagement.

**Code 319 misclassification across two consecutive tax years (referral case).** A client referred through a colleague was misclassified under code 319 for two consecutive years. Recommended path: residency correction, then amended returns for both years, then the current-year filing. Illustrates that the code 319 pattern above is not limited to a single year once it starts.

**Residency change bundled with a prior-year amended return.** A client's residency change was locked from a prior year; the resolved plan was a current-year filing as resident plus one amended return for the locked year. Useful as a worked template for bundling a residency correction with a prior-year amended return as a single engagement rather than two separate ones.

**Outbound proposal parked adjacent to an active 5C claim.** A client pair with an active 5C regime claim (foreign dividend income) had outbound residency transfer under discussion (candidate destinations: Switzerland, Spain), parked pending an internal decision on whether to proceed. Illustrates the 5C interaction flagged above: an outbound transfer while a 5C claim is live needs deliberate scoping, not a default yes.

**Estate case surfacing a residency-adjacent question.** An estate/inheritance case required TAXISnet and myAADE activation for an heir, which in turn depended on resolving a family registration gap in Greece. Worth tracking here because estate cases can surface a residency question for the heir as a side effect, even though the case itself is not a standard residency transfer.

**Open scope question: is a tax representative needed.** A client had partially self-obtained an AFM, stalled mid-process, with a short-term visit to Greece upcoming. The open question, whether a Greek tax representative is required for a non-resident client in this position, is functionally an inbound-adjacent decision and depends on partner input on non-resident-abroad AFM handling (see the pending pricing question in `pricing/price-table.md`).

## Changelog

- 2026-07-12: created as draft scaffold
- 2026-07-13: consolidated with operational knowledge (code 319 rule, sequencing rule, outbound authorization pattern), OECD framework, expanded source checklist by form and by treaty country, partner-verification list, and anonymized edge cases. Pricing content removed from this file per rule R2, now lives exclusively in `pricing/price-table.md`. Primary-source research pass (AADE/ΠΟΛ/ΣΑΔΦ) still outstanding; "The rule" section remains DRAFT pending that pass and partner sign-off, particularly on split-year treatment.
