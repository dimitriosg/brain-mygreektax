-- Migration: restore the knowledge governance model
-- Adds the columns the live knowledge_base is missing (status, source, tax_year, review_by)
-- so the Lambda can re-enable the canonical-only injection gate and staleness flagging.
-- Existing rows default to status 'draft', which means they stop being injected
-- until reviewed and promoted. That is intentional: fail closed.
-- Save this file to supabase/migrations/ in the repo after running it.

-- 1. knowledge_base governance columns
alter table knowledge_base add column if not exists status text not null default 'draft';
alter table knowledge_base add column if not exists source text;
alter table knowledge_base add column if not exists tax_year int;
alter table knowledge_base add column if not exists review_by date;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'knowledge_base_status_check'
  ) then
    alter table knowledge_base
      add constraint knowledge_base_status_check
      check (status in ('draft', 'canonical'));
  end if;
end $$;

-- Needed for idempotent seeding (insert ... on conflict (slug) do nothing)
create unique index if not exists knowledge_base_slug_key on knowledge_base (slug);

comment on table knowledge_base is
  'Injected into Brain prompts. Only rows with status = canonical AND is_active AND visibility = client_safe are ever injected into client drafting. No client PII, no pricing figures, ever. Rows past review_by are injected flagged as needing re-verification.';

-- 2. knowledge_candidates: Brain-proposed learnings. Never read back into any prompt.
create table if not exists knowledge_candidates (
  id uuid primary key default gen_random_uuid(),
  case_id uuid,
  title text not null,
  content text not null,
  category text,
  rationale text,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

alter table knowledge_candidates add column if not exists category text;
alter table knowledge_candidates add column if not exists rationale text;
alter table knowledge_candidates add column if not exists reviewed_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'knowledge_candidates_status_check'
  ) then
    alter table knowledge_candidates
      add constraint knowledge_candidates_status_check
      check (status in ('pending', 'approved', 'rejected'));
  end if;
end $$;

comment on table knowledge_candidates is
  'Brain-proposed learnings awaiting human review. Anonymized patterns only. Rows here are NEVER injected into any prompt. Promotion means Jim manually creates a knowledge_base row from an approved candidate.';

-- 3. RLS
alter table knowledge_base enable row level security;
alter table knowledge_candidates enable row level security;

drop policy if exists portal_read_kb on knowledge_base;
create policy portal_read_kb on knowledge_base
  for select to authenticated using (true);

drop policy if exists portal_update_kb on knowledge_base;
create policy portal_update_kb on knowledge_base
  for update to authenticated using (true);

drop policy if exists portal_read_candidates on knowledge_candidates;
create policy portal_read_candidates on knowledge_candidates
  for select to authenticated using (true);

drop policy if exists portal_update_candidates on knowledge_candidates;
create policy portal_update_candidates on knowledge_candidates
  for update to authenticated using (true);

notify pgrst, 'reload schema';
