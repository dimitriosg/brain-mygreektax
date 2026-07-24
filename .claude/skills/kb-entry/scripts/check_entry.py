#!/usr/bin/env python3
"""Check a MyGreekTax knowledge entry before it is promoted.

Reads both shapes:

  wiki page   a markdown page with a "Status:" header block, per
              wiki/rules/_TEMPLATE_rule.md
  kb row      YAML front matter matching the knowledge_base columns, per
              .claude/skills/kb-entry/assets/kb-row-template.md

It validates the field set, source presence and shape, review staleness, and
scans for what must never appear in permanent knowledge: client PII (R1),
pricing figures (R2), and dashes (R5).

It cannot judge whether the tax content is correct. That is the licensed
partner's job, and R3 lists what always needs partner confirmation.

Usage:
    python check_entry.py wiki/rules/tax-residency-transfer.md
    python check_entry.py wiki/
    python check_entry.py wiki/ --json
"""

import argparse
import datetime as dt
import json
import os
import re
import sys

# --- kb row (YAML front matter) --------------------------------------------
ROW_REQUIRED = ["slug", "title", "category", "visibility", "status", "source", "review_by"]
CATEGORIES = {"rules", "sops", "services", "regimes", "style"}
VISIBILITIES = {"client_safe", "internal_only"}
ROW_STATUSES = {"draft", "canonical"}
SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
FRONT_MATTER = re.compile(r"^---\s*\n(.*?)\n---\s*\n(.*)$", re.DOTALL)

# --- wiki page (Status: header block) --------------------------------------
WIKI_TITLE = re.compile(r"^#\s+(.+?)\s*$", re.MULTILINE)
WIKI_FIELD = re.compile(r"^(Status|Last reviewed|Affects services|Affects)\s*:\s*(.+?)\s*$", re.MULTILINE)
WIKI_STATUS_VALUE = re.compile(r"^(DRAFT|CANONICAL)\b", re.IGNORECASE)
STALE_AFTER_DAYS = 365

# --- shared ----------------------------------------------------------------
SOURCE_OK = re.compile(
    r"(aade|gov\.gr|myaade|ΠΟΛ|Ε\.?\s?\d|circular|law\s*\d|ν\.?\s*\d|νόμος|treaty|ΣΑΔΦ|oecd|article\s*\d"
    r"|per\s+[Α-Ωα-ωA-Za-z]+,\s*\d{4}-\d{2}-\d{2}|https?://)",
    re.IGNORECASE,
)
SOURCE_SUSPECT = re.compile(
    r"(notebooklm|chatgpt|\bclaude\b|gemini|ai[\s\-]?generated|ai\s+synthesis|summary\s+of\s+a\s+summary)",
    re.IGNORECASE,
)

PII_PATTERNS = [
    (r"(?<!\d)\d{9}(?!\d)", "nine digit number, possibly an AFM"),
    (r"[\w\.\-\+]+@[\w\-]+\.[a-z]{2,}", "email address"),
    (r"\b(?:GR|DE|GB|PT|NL|FR|ES|IT|CY)\d{2}[\s\d]{12,}", "IBAN"),
    (r"\+\d{1,3}[\s\-]?\d[\d\s\-]{8,}", "phone number"),
    (r"\bCLT\d{4}", "client code"),
    (r"\bMGT-CS\d{3}", "case serial"),
]

MONEY = re.compile(r"(?:€\s?\d|(?<![A-Za-z0-9])\d{1,5}(?:[.,]\d{2})?\s?(?:€|EUR\b|euros?\b))", re.IGNORECASE)
DASHES = re.compile(r"[\u2014\u2013]")
FIREWALL_TERMS = ["wholesale", "margin", "markup", "retail price", "Παράρτημα Α"]

SKIP_BASENAMES = {"index.md"}


def strip_comments(text):
    return re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)


def is_template(path, text):
    base = os.path.basename(path)
    return base.startswith("_TEMPLATE") or "kb-row-template" in base or "(Rule topic)" in text


def check_prohibitions(body, errors, warnings):
    for pattern, label in PII_PATTERNS:
        for match in re.finditer(pattern, body):
            snippet = match.group(0)
            if label.startswith("nine digit") and re.match(r"(19|20)\d{2}", snippet):
                continue
            errors.append(f"possible {label} in content ({snippet[:6]}...); R1, no client PII in permanent files")
            break

    for match in MONEY.finditer(body):
        errors.append(
            f"currency figure in content ({match.group(0).strip()}); R2, figures live only in pricing/price-table.md"
        )
        break

    if DASHES.search(body):
        errors.append("contains an em dash or en dash; R5, use commas, colons or parentheses")


def check_source(source_text, errors, warnings):
    if not source_text:
        return
    if SOURCE_SUSPECT.search(source_text):
        errors.append(
            "sources cite generated or secondary material; "
            "cite the primary authority or a dated partner confirmation, per R4"
        )
    elif not SOURCE_OK.search(source_text):
        warnings.append(
            "sources do not obviously name a primary authority "
            "(AADE page with URL, law or circular number, treaty article, or 'per [partner], YYYY-MM-DD')"
        )


def check_row(path, fields, body, errors, warnings):
    for key in ROW_REQUIRED:
        if not fields.get(key):
            errors.append(f"missing required field '{key}'")

    slug = fields.get("slug", "")
    if slug and not SLUG_RE.match(slug):
        errors.append(f"slug {slug!r} must be lower case and hyphen separated")
    if slug.startswith("subject-in-"):
        errors.append("slug is still the template placeholder")

    category = fields.get("category", "")
    if category and category not in CATEGORIES:
        warnings.append(f"category {category!r} is not one of {sorted(CATEGORIES)}")

    visibility = fields.get("visibility", "")
    if visibility and visibility not in VISIBILITIES:
        errors.append(f"visibility must be one of {sorted(VISIBILITIES)}")

    status = fields.get("status", "").lower()
    if status and status not in ROW_STATUSES:
        errors.append(f"status must be one of {sorted(ROW_STATUSES)}")
    if status == "canonical":
        warnings.append("status is canonical; confirm Δημήτρης promoted this. Entries are created as draft")

    review_by = fields.get("review_by", "")
    if review_by:
        try:
            when = dt.date.fromisoformat(review_by)
            if when < dt.date.today():
                warnings.append(f"review_by {review_by} has passed; re-verify before relying on this")
        except ValueError:
            errors.append(f"review_by {review_by!r} is not an ISO date")

    check_source(fields.get("source", ""), errors, warnings)

    if visibility == "client_safe":
        for term in FIREWALL_TERMS:
            if term.lower() in body.lower():
                errors.append(f"visibility is client_safe but content mentions {term!r}")
                break


def check_wiki(path, text, body, errors, warnings):
    if not WIKI_TITLE.search(text):
        errors.append("no '# Title' heading")

    fields = {k.lower(): v for k, v in WIKI_FIELD.findall(text)}

    status = fields.get("status", "")
    if not status:
        errors.append("no 'Status:' line; every wiki page carries DRAFT or CANONICAL, per R4")
    elif not WIKI_STATUS_VALUE.match(status):
        errors.append(f"Status: {status!r} must start with DRAFT or CANONICAL")
    elif status.upper().startswith("CANONICAL") and not re.search(r"^\s*-\s*\d{4}-\d{2}-\d{2}", text, re.MULTILINE):
        warnings.append(
            "Status is CANONICAL but no dated changelog line records the promotion; "
            "pages are created as DRAFT and only Δημήτρης promotes"
        )

    reviewed = fields.get("last reviewed", "")
    if not reviewed:
        errors.append("no 'Last reviewed:' line")
    else:
        try:
            when = dt.date.fromisoformat(reviewed.strip())
            age = (dt.date.today() - when).days
            if age > STALE_AFTER_DAYS:
                warnings.append(f"last reviewed {reviewed} ({age} days ago); re-verify the sources")
        except ValueError:
            errors.append(f"Last reviewed: {reviewed!r} is not an ISO date (YYYY-MM-DD)")

    if not (fields.get("affects services") or fields.get("affects")):
        warnings.append("no 'Affects services:' line; without it the page is hard to find from a case")

    # R4 requires a source for every factual tax claim. Pages under rules/ and
    # regimes/ make tax claims; sops/, style/ and services.md state internal
    # policy, where an external source is not always meaningful.
    makes_tax_claims = any(part in os.path.dirname(path).replace(os.sep, "/") for part in ("rules", "regimes"))
    m = re.search(r"^##\s*Sources\s*$(.*?)(?=^##\s|\Z)", text, re.MULTILINE | re.DOTALL)
    if not m:
        msg = "no '## Sources' section; R4 requires a source for every factual tax claim"
        (errors if makes_tax_claims else warnings).append(msg)
    else:
        block = m.group(1).strip()
        if len(block) < 20:
            errors.append("'## Sources' section is empty or near empty")
        else:
            check_source(block, errors, warnings)

    if "changelog" not in text.lower():
        warnings.append("no changelog section; corrections to a canonical page need a dated line")

    slug_candidate = os.path.splitext(os.path.basename(path))[0]
    if not SLUG_RE.match(slug_candidate):
        warnings.append(
            f"filename {slug_candidate!r} does not make a valid slug; "
            f"it becomes the knowledge_base slug and slugs are permanent"
        )


def check_entry(path):
    errors, warnings = [], []
    try:
        with open(path, encoding="utf-8") as fh:
            raw = fh.read()
    except OSError as e:
        return [f"cannot read: {e}"], [], "unknown"

    if is_template(path, raw):
        return [], [], "template"

    m = FRONT_MATTER.match(raw)
    if m:
        fields = {}
        for line in m.group(1).splitlines():
            line = line.strip()
            if not line or line.startswith("#") or ":" not in line:
                continue
            key, _, value = line.partition(":")
            fields[key.strip().lower()] = value.strip().strip('"').strip("'")
        body = strip_comments(m.group(2))
        check_row(path, fields, body, errors, warnings)
        check_prohibitions(body, errors, warnings)
        return errors, warnings, "kb row"

    body = strip_comments(raw)
    check_wiki(path, raw, body, errors, warnings)
    check_prohibitions(body, errors, warnings)
    return errors, warnings, "wiki page"


def main():
    ap = argparse.ArgumentParser(description="Check a MyGreekTax knowledge entry.")
    ap.add_argument("path")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    targets = []
    if os.path.isdir(args.path):
        for dirpath, dirnames, filenames in os.walk(args.path):
            dirnames[:] = [d for d in dirnames if not d.upper().startswith("OLD")]
            for name in sorted(filenames):
                if name.lower().endswith(".md") and name.lower() not in SKIP_BASENAMES:
                    targets.append(os.path.join(dirpath, name))
    else:
        targets.append(args.path)

    results = {}
    total_errors = 0
    for path in targets:
        errors, warnings, kind = check_entry(path)
        results[path] = {"kind": kind, "errors": errors, "warnings": warnings}
        total_errors += len(errors)

    if args.json:
        print(json.dumps(results, indent=2, ensure_ascii=False))
        return 1 if total_errors else 0

    for path, res in results.items():
        if res["kind"] == "template":
            continue
        print(f"{path}  [{res['kind']}]")
        for e in res["errors"]:
            print(f"  ERROR    {e}")
        for w in res["warnings"]:
            print(f"  WARNING  {w}")
        if not res["errors"] and not res["warnings"]:
            print("  clean")
        print()

    checked = [r for r in results.values() if r["kind"] != "template"]
    if total_errors:
        print(f"FAILED: {total_errors} error(s) across {len(checked)} entry/entries.")
        return 1
    print(f"PASSED: {len(checked)} entry/entries have no errors.")
    print("Content accuracy is still unverified. Check each claim against its cited source, and route R3 items to the partner.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except BrokenPipeError:
        sys.exit(0)
