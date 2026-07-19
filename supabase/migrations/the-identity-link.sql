-- Link a case (brain_conversations) to a customer (clients) and give it a serial ID.
-- Additive only. The live case_timeline / case_drafts pipeline does not read this
-- table, so nothing currently running is affected.

alter table brain_conversations
  add column if not exists client_id uuid references clients(id) on delete set null,
  add column if not exists case_serial_id text,
  add column if not exists case_number integer,
  add column if not exists stage text not null default 'Potential';

create unique index if not exists brain_conversations_case_serial_key
  on brain_conversations (case_serial_id)
  where case_serial_id is not null;

create index if not exists brain_conversations_client_id_idx
  on brain_conversations (client_id);

create index if not exists brain_conversations_customer_email_idx
  on brain_conversations (lower(customer_email));
