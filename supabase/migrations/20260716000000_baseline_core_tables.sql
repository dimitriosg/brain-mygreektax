-- ============================================================================
-- Baseline: core Brain tables (clients, brain_conversations, brain_events)
-- ============================================================================
-- These three tables were created directly in the Supabase SQL editor and were
-- never committed as migration files. Every later migration assumes they exist,
-- so the migration chain could not rebuild the database from empty. This file
-- closes that gap.
--
-- Reconstructed from the live production schema (project igfwqgiscjpshxfsyunq)
-- and deliberately trimmed back to the pre-2026-07-17 shape: columns, indexes
-- and constraints that later committed migrations add are NOT included here,
-- so the chain still replays authentically.
--
-- Specifically excluded, and left to the migrations that own them:
--   brain_conversations.client_id, case_serial_id, case_number, stage
--     -> 20260717000000_brain_session_consolidated.sql
--   brain_conversations.archived_at
--     -> 20260719140000_case_archive_delete.sql
--   RLS enablement and all policies on these tables
--     -> 20260717000000_brain_session_consolidated.sql
--
-- Idempotent: safe to run against a database where these tables already exist.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- clients: the customer record. client_code is the human-readable CLTxxxx id.
-- ----------------------------------------------------------------------------
create table if not exists public.clients (
  id uuid default gen_random_uuid() not null,
  client_code text,
  full_name text,
  email text,
  phone text,
  status text,
  stage text,
  source text,
  urgency text,
  notes text,
  lead_value numeric,
  lost_reason text,
  next_action text,
  next_action_date date,
  last_activity timestamp with time zone,
  nationality text,
  afm text,
  taxisnet_access boolean,
  cadence text,
  case_code text,
  quote_sent_date date,
  quote_amount numeric,
  deposit numeric,
  balance_due numeric,
  partner_fee numeric,
  parked_reason text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  client_visible_note text,
  thread_id text,
  gmail_sent_last_sync timestamp with time zone,
  constraint clients_pkey primary key (id),
  constraint clients_client_code_key unique (client_code)
);

create index if not exists clients_email_idx on public.clients using btree (lower(email));
create index if not exists clients_stage_idx on public.clients using btree (stage);

-- ----------------------------------------------------------------------------
-- brain_conversations: one row per case thread.
-- ----------------------------------------------------------------------------
create table if not exists public.brain_conversations (
  id uuid default gen_random_uuid() not null,
  customer_id text not null,
  lead_id text,
  job_id text,
  subject text,
  conversation_type text default 'lead'::text not null,
  status text default 'active'::text not null,
  partner_required boolean default false not null,
  partner_input_status text default 'not_required'::text not null,
  customer_email text not null,
  partner_email text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  closed_at timestamp with time zone,
  constraint brain_conversations_pkey primary key (id),
  constraint brain_conversations_conversation_type_check
    check (conversation_type = any (array['lead'::text, 'job'::text, 'follow_up'::text, 'other'::text])),
  constraint brain_conversations_partner_input_status_check
    check (partner_input_status = any (array['not_required'::text, 'requested'::text, 'received'::text, 'not_needed'::text])),
  constraint brain_conversations_status_check
    check (status = any (array['active'::text, 'awaiting_customer_reply'::text, 'awaiting_partner_reply'::text,
                               'awaiting_both_replies'::text, 'ready_for_analysis'::text,
                               'draft_ready_for_review'::text, 'closed'::text, 'needs_routing_review'::text]))
);

create index if not exists brain_conversations_customer_id_idx
  on public.brain_conversations using btree (customer_id);
create index if not exists brain_conversations_job_id_idx
  on public.brain_conversations using btree (job_id) where (job_id is not null);
create index if not exists brain_conversations_lead_id_idx
  on public.brain_conversations using btree (lead_id) where (lead_id is not null);
create index if not exists brain_conversations_open_email_idx
  on public.brain_conversations using btree (lower(customer_email), status) where (status <> 'closed'::text);

-- ----------------------------------------------------------------------------
-- brain_events: append-only event log per conversation.
-- external_event_id is the idempotency key for inbound ingestion.
-- ----------------------------------------------------------------------------
create table if not exists public.brain_events (
  id uuid default gen_random_uuid() not null,
  conversation_id uuid not null,
  external_event_id text not null,
  event_type text not null,
  actor text not null,
  direction text,
  provider text,
  provider_message_id text,
  provider_thread_id text,
  in_reply_to_message_id text,
  email_references text[] default '{}'::text[] not null,
  from_email text,
  to_emails text[] default '{}'::text[] not null,
  subject text,
  body_text text,
  metadata jsonb default '{}'::jsonb not null,
  occurred_at timestamp with time zone default now() not null,
  created_at timestamp with time zone default now() not null,
  constraint brain_events_pkey primary key (id),
  constraint brain_events_external_event_id_key unique (external_event_id),
  constraint brain_events_conversation_id_fkey
    foreign key (conversation_id) references public.brain_conversations(id) on delete cascade,
  constraint brain_events_actor_check
    check (actor = any (array['customer'::text, 'partner'::text, 'dimitris'::text, 'system'::text])),
  constraint brain_events_direction_check
    check (direction = any (array['inbound'::text, 'outbound'::text, 'internal'::text])),
  constraint brain_events_event_type_check
    check (event_type = any (array['lead_created'::text, 'triage_completed'::text, 'customer_email_received'::text,
                                   'customer_email_sent'::text, 'partner_email_sent'::text,
                                   'partner_email_received'::text, 'internal_note'::text, 'job_linked'::text,
                                   'draft_created'::text, 'draft_approved'::text, 'draft_rejected'::text]))
);

create index if not exists brain_events_conversation_time_idx
  on public.brain_events using btree (conversation_id, occurred_at);
create index if not exists brain_events_provider_message_idx
  on public.brain_events using btree (provider_message_id) where (provider_message_id is not null);
create index if not exists brain_events_reply_to_idx
  on public.brain_events using btree (in_reply_to_message_id) where (in_reply_to_message_id is not null);
create index if not exists brain_events_thread_idx
  on public.brain_events using btree (provider_thread_id) where (provider_thread_id is not null);
create unique index if not exists brain_events_unique_provider_message_idx
  on public.brain_events using btree (provider, provider_message_id) where (provider_message_id is not null);
