-- ============================================================================
-- Baseline: the 16 production tables that no migration creates
-- ============================================================================
-- These tables were created directly in the Supabase SQL editor and were never
-- committed as migration files. Sixteen of production's forty public tables are
-- in this state, so the migration chain could not rebuild the database from
-- empty. This file closes that gap.
--
-- The first three below (clients, brain_conversations, brain_events) are the
-- ones that break the chain outright: 20260717000000_brain_session_consolidated
-- alters brain_conversations, so it cannot run on a fresh database without them.
-- The rest are unreferenced by any migration but are needed for the schema to
-- match production.
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

-- ============================================================================
-- Remaining tables that no migration creates
-- ============================================================================
-- Same defect as the three above: these exist in production only because they
-- were created in the SQL editor. Ordered by foreign-key dependency so the file
-- applies cleanly to an empty database.
--
-- RLS: production has row level security enabled on every public table,
-- including these (deny-all where no policy exists; the service role bypasses
-- RLS). An earlier version of this comment claimed it was disabled, which was
-- wrong. Enablement lives in 20260731120000_baseline_handmade_objects_and_rls
-- so the two files stay consistent with the order they were applied in.
-- ============================================================================

create table if not exists public.accountants (
  id uuid default gen_random_uuid() not null,
  name text,
  email text,
  status text,
  specialty text,
  phone text,
  notes text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  partner_progress_notes text,
  current_workload numeric,
  constraint accountants_pkey primary key (id)
);

create table if not exists public.service_catalog (
  id uuid default gen_random_uuid() not null,
  airtable_id text,
  service_code text,
  service_name text,
  category text,
  tier text,
  base_client_price numeric,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  notes text,
  constraint service_catalog_pkey primary key (id),
  constraint service_catalog_airtable_id_key unique (airtable_id),
  constraint service_catalog_service_code_key unique (service_code)
);

create table if not exists public.case_drafts (
  id uuid default gen_random_uuid() not null,
  case_id uuid not null,
  proposed_draft text not null,
  internal_notes text,
  is_approved boolean default false,
  last_updated timestamp with time zone default now(),
  constraint case_drafts_pkey primary key (id),
  constraint case_drafts_case_id_key unique (case_id)
);

create table if not exists public.case_timeline (
  id uuid default gen_random_uuid() not null,
  case_id uuid not null,
  event_type character varying not null,
  sender character varying not null,
  payload jsonb not null,
  created_at timestamp with time zone default now(),
  case_serial_id text,
  source_message_id text,
  constraint case_timeline_pkey primary key (id)
);

create table if not exists public.cases_directory (
  id uuid default gen_random_uuid() not null,
  case_serial_id character varying not null,
  client_serial_id character varying not null,
  status character varying default 'review_pending'::character varying,
  created_at timestamp with time zone default now(),
  constraint cases_directory_pkey primary key (id),
  constraint cases_directory_case_serial_id_key unique (case_serial_id)
);

create table if not exists public.outbound_emails (
  id uuid default gen_random_uuid() not null,
  message_id text,
  sender text not null,
  recipient text not null,
  subject text,
  body text,
  headers jsonb default '{}'::jsonb,
  "timestamp" timestamp with time zone default now(),
  is_lead boolean default false,
  constraint outbound_emails_pkey primary key (id),
  constraint outbound_emails_message_id_key unique (message_id)
);

create table if not exists public.messages (
  id uuid default gen_random_uuid() not null,
  airtable_id text,
  message_id text,
  client_id uuid,
  direction text,
  ts timestamp with time zone,
  subject text,
  body text,
  thread_id text,
  from_addr text,
  to_addr text,
  created_at timestamp with time zone default now() not null,
  constraint messages_pkey primary key (id),
  constraint messages_airtable_id_key unique (airtable_id),
  constraint messages_client_id_fkey foreign key (client_id) references public.clients(id) on delete cascade
);

create table if not exists public.newsletter_subscribers (
  id uuid default gen_random_uuid() not null,
  email text not null,
  full_name text,
  status text default 'pending'::text not null,
  source text,
  client_id uuid,
  emailoctopus_id text,
  subscribed_at timestamp with time zone,
  unsubscribed_at timestamp with time zone,
  confirmed_at timestamp with time zone,
  last_synced_at timestamp with time zone,
  tags text[],
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  constraint newsletter_subscribers_pkey primary key (id),
  constraint newsletter_subscribers_email_key unique (email),
  constraint newsletter_subscribers_client_id_fkey foreign key (client_id) references public.clients(id) on delete set null
);

create table if not exists public.jobs (
  id uuid default gen_random_uuid() not null,
  job_code text,
  status text,
  next_action_needed text,
  client_id uuid,
  accountant_id uuid,
  service_id uuid,
  date_sent date,
  sla_deadline date,
  accountant_fee numeric,
  client_fee numeric,
  admin_internal_notes text,
  partner_progress_notes text,
  client_visible_note text,
  notes text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  constraint jobs_pkey primary key (id),
  constraint jobs_job_code_key unique (job_code),
  constraint jobs_accountant_id_fkey foreign key (accountant_id) references public.accountants(id) on delete set null,
  constraint jobs_client_id_fkey foreign key (client_id) references public.clients(id) on delete set null,
  constraint jobs_service_id_fkey foreign key (service_id) references public.service_catalog(id) on delete set null
);

create table if not exists public.brain_ai_runs (
  id uuid default gen_random_uuid() not null,
  conversation_id uuid not null,
  trigger_event_id uuid,
  run_type text not null,
  provider text default 'anthropic'::text not null,
  model text not null,
  prompt_version text not null,
  status text default 'queued'::text not null,
  input_tokens integer,
  output_tokens integer,
  cache_creation_input_tokens integer,
  cache_read_input_tokens integer,
  estimated_cost_usd numeric(12,6),
  input_summary jsonb default '{}'::jsonb not null,
  output jsonb,
  error_message text,
  started_at timestamp with time zone,
  completed_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  constraint brain_ai_runs_pkey primary key (id),
  constraint brain_ai_runs_conversation_id_fkey foreign key (conversation_id) references public.brain_conversations(id) on delete cascade,
  constraint brain_ai_runs_trigger_event_id_fkey foreign key (trigger_event_id) references public.brain_events(id) on delete set null,
  constraint brain_ai_runs_run_type_check check (run_type = any (array['lead_import'::text, 'state_update'::text, 'strategy'::text, 'draft'::text, 'summary'::text])),
  constraint brain_ai_runs_status_check check (status = any (array['queued'::text, 'running'::text, 'succeeded'::text, 'failed'::text, 'skipped'::text]))
);

create table if not exists public.brain_drafts (
  id uuid default gen_random_uuid() not null,
  conversation_id uuid not null,
  ai_run_id uuid,
  draft_type text not null,
  subject text,
  body_text text not null,
  status text default 'pending_review'::text not null,
  edited_subject text,
  edited_body_text text,
  approved_by uuid,
  approved_at timestamp with time zone,
  sent_at timestamp with time zone,
  sent_event_id uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  constraint brain_drafts_pkey primary key (id),
  constraint brain_drafts_conversation_id_fkey foreign key (conversation_id) references public.brain_conversations(id) on delete cascade,
  constraint brain_drafts_ai_run_id_fkey foreign key (ai_run_id) references public.brain_ai_runs(id) on delete set null,
  constraint brain_drafts_sent_event_id_fkey foreign key (sent_event_id) references public.brain_events(id) on delete set null,
  constraint brain_drafts_draft_type_check check (draft_type = any (array['customer_email'::text, 'partner_email'::text, 'internal_summary'::text])),
  constraint brain_drafts_status_check check (status = any (array['pending_review'::text, 'approved'::text, 'rejected'::text, 'superseded'::text, 'sent'::text]))
);

create table if not exists public.brain_approval_tasks (
  id uuid default gen_random_uuid() not null,
  conversation_id uuid not null,
  draft_id uuid,
  task_type text default 'review_draft'::text not null,
  status text default 'open'::text not null,
  priority text default 'normal'::text not null,
  title text not null,
  instructions text,
  assigned_to uuid,
  resolved_by uuid,
  resolved_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  constraint brain_approval_tasks_pkey primary key (id),
  constraint brain_approval_tasks_conversation_id_fkey foreign key (conversation_id) references public.brain_conversations(id) on delete cascade,
  constraint brain_approval_tasks_draft_id_fkey foreign key (draft_id) references public.brain_drafts(id) on delete cascade,
  constraint brain_approval_tasks_priority_check check (priority = any (array['low'::text, 'normal'::text, 'high'::text, 'urgent'::text])),
  constraint brain_approval_tasks_status_check check (status = any (array['open'::text, 'approved'::text, 'rejected'::text, 'completed'::text, 'cancelled'::text])),
  constraint brain_approval_tasks_task_type_check check (task_type = any (array['review_draft'::text, 'route_conversation'::text, 'resolve_conflict'::text, 'request_partner_input'::text]))
);

create table if not exists public.brain_states (
  conversation_id uuid not null,
  version integer default 1 not null,
  state jsonb default '{}'::jsonb not null,
  last_processed_event_id uuid,
  last_analysis_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  constraint brain_states_pkey primary key (conversation_id),
  constraint brain_states_conversation_id_fkey foreign key (conversation_id) references public.brain_conversations(id) on delete cascade,
  constraint brain_states_last_processed_event_id_fkey foreign key (last_processed_event_id) references public.brain_events(id) on delete set null
);
