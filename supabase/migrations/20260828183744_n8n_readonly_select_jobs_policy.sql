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

notify pgrst, 'reload schema';
