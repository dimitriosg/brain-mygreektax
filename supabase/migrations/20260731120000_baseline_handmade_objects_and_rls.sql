-- ============================================================================
-- Baseline follow-up: hand-made objects and the RLS correction
-- ============================================================================
-- Closes the residual gap between the migration chain and production found by
-- a full diff after 20260716000000_baseline_core_tables.sql:
--
-- 1. RLS CORRECTION. The baseline stated RLS was off in production on the 13
--    orphan tables. That was wrong: production has RLS enabled on every public
--    table, including tables with no policies, which are deny-all for anon and
--    authenticated (the service role bypasses RLS). Leaving RLS off made a
--    rebuilt database MORE permissive than production. Enabled here.
--
-- 2. Two objects hand-made in production and never committed:
--    - portal_read_timeline on case_timeline
--    - lookup_case_uuid_by_serial(), the serial-to-uuid lookup used by the
--      Make.com inbound pipeline against cases_directory
--
-- Known residual drift, deliberately NOT reproduced here:
--    - resolve_case_for_inbound(text, text, text): a legacy 3-argument
--      overload still present in production alongside the current 7-argument
--      version. Nothing in either repo creates it. Recommend DROPPING it in
--      production rather than committing it.
--    - cleanup_tracking_link_opens(): created by committed migration
--      20260513173500_tracking_privacy_retention.sql but ABSENT in production.
--      Reverse drift: either that migration never ran in production or the
--      function was dropped by hand. Needs a decision, not a baseline entry.
--
-- Idempotent throughout.
-- ============================================================================

alter table public.accountants            enable row level security;
alter table public.brain_ai_runs          enable row level security;
alter table public.brain_approval_tasks   enable row level security;
alter table public.brain_drafts           enable row level security;
alter table public.brain_states           enable row level security;
alter table public.case_drafts            enable row level security;
alter table public.case_timeline          enable row level security;
alter table public.cases_directory        enable row level security;
alter table public.jobs                   enable row level security;
alter table public.messages               enable row level security;
alter table public.newsletter_subscribers enable row level security;
alter table public.outbound_emails        enable row level security;
alter table public.service_catalog        enable row level security;

drop policy if exists portal_read_timeline on public.case_timeline;
create policy portal_read_timeline
  on public.case_timeline
  for select
  to authenticated
  using (true);

CREATE OR REPLACE FUNCTION public.lookup_case_uuid_by_serial(search_serial text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    found_uuid UUID;
BEGIN
    SELECT id INTO found_uuid
    FROM cases_directory
    WHERE case_serial_id = search_serial
    LIMIT 1;

    RETURN found_uuid;
END;
$function$;
