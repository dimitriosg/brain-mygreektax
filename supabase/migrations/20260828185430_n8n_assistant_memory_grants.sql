-- Role n8n_assistant is created by hand in the Supabase SQL editor, because it
-- carries a password and a password must not live in a migration file:
--
--   create role n8n_assistant with login password '<set in the editor>';
--
-- Everything else about the role lives here.
--
-- It exists so the case assistant can persist chat history without widening
-- n8n_readonly, which stays read-only. This role reaches exactly one table.
-- The create privilege on schema public is needed only because the n8n Postgres
-- Chat Memory node runs create table if not exists on every connect. Verified
-- 28/08: revoking create breaks the node with "permission denied for schema
-- public" even when the table already exists.

grant usage, create on schema public to n8n_assistant;

grant select, insert, update, delete on public.mgt_assistant_memory to n8n_assistant;
grant usage, select on sequence public.mgt_assistant_memory_id_seq to n8n_assistant;

drop policy if exists n8n_assistant_all_mgt_assistant_memory on public.mgt_assistant_memory;
create policy n8n_assistant_all_mgt_assistant_memory
  on public.mgt_assistant_memory
  for all
  to n8n_assistant
  using (true)
  with check (true);

notify pgrst, 'reload schema';
