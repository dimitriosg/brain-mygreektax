-- The n8n Postgres credential connects as n8n_readonly, which holds
-- column-level SELECT grants rather than table-level ones. The owner split in
-- the morning digest and the case assistant both need jobs.next_action_needed,
-- so this extends the same pattern to jobs.
--
-- Deliberately NOT granted: accountant_fee and client_fee (wholesale and
-- retail), accountant_id, service_id. n8n has no reason to see partner pricing
-- and this keeps that closed.

grant select (
  client_id,
  job_code,
  status,
  next_action_needed,
  date_sent,
  sla_deadline,
  partner_progress_notes,
  admin_internal_notes,
  created_at
) on public.jobs to n8n_readonly;

notify pgrst, 'reload schema';

-- The column grant alone is not enough. jobs has RLS enabled and n8n_readonly
-- neither owns it nor bypasses RLS, so without a policy the query succeeds and
-- returns nothing. That is the silent version of the same failure.
-- Matches the existing n8n_readonly_select_<table> policies on clients,
-- brain_conversations and payment_tokens.

drop policy if exists n8n_readonly_select_jobs on public.jobs;
create policy n8n_readonly_select_jobs
  on public.jobs
  for select
  to n8n_readonly
  using (true);
