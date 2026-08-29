-- Chat memory for the n8n workflow "20 · Case assistant" (CXQ0gHwIFO8BtZls).
-- Shape is fixed by LangChain's PostgresChatMessageHistory, which the n8n
-- Postgres Chat Memory node uses. The node would create this table on first
-- run; it is created here instead so the schema is owned by a migration and
-- not by whichever workflow happened to run first.

create table if not exists public.mgt_assistant_memory (
  id         serial primary key,
  session_id text  not null,
  message    jsonb not null
);

create index if not exists mgt_assistant_memory_session_id_idx
  on public.mgt_assistant_memory (session_id);

-- Agent turns, not case data, but they quote case data freely, so RLS is on.
-- Access is granted explicitly to the n8n_assistant role in a later migration.
-- Nothing else reaches this table.
alter table public.mgt_assistant_memory enable row level security;

comment on table public.mgt_assistant_memory is
  'Chat history for the n8n case assistant. One row per agent turn. session_id is the surface key, currently the single shared key "jim". Safe to clear out: it is conversation history, not a system of record.';

notify pgrst, 'reload schema';
