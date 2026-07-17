-- knowledge_base: what the Brain is allowed to know
create table if not exists knowledge_base (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title text not null,
  content text not null,
  category text not null,
  visibility text not null default 'internal_only'
    check (visibility in ('client_safe','partner_safe','internal_only')),
  status text not null default 'draft'
    check (status in ('draft','canonical')),
  source text,
  tax_year int,
  review_by date,
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

comment on table knowledge_base is
  'Injected into Brain prompts. Only status=canonical AND is_active rows are ever injected. No client PII, no pricing figures, ever.';

-- knowledge_candidates: what the Brain proposes to learn. Never injected.
create table if not exists knowledge_candidates (
  id uuid primary key default gen_random_uuid(),
  case_id uuid,
  title text not null,
  content text not null,
  category text,
  rationale text,
  status text not null default 'pending'
    check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

comment on table knowledge_candidates is
  'Brain-proposed learnings awaiting human review. Content must be anonymized patterns only. Rows here are NEVER read back into any prompt.';

alter table knowledge_base enable row level security;
alter table knowledge_candidates enable row level security;

create policy "portal_read_kb" on knowledge_base
  for select to authenticated using (true);
create policy "portal_read_candidates" on knowledge_candidates
  for select to authenticated using (true);
create policy "portal_update_candidates" on knowledge_candidates
  for update to authenticated using (true);

notify pgrst, 'reload schema';
