-- Record the live body of the 7-arg resolve_case_for_inbound.
--
-- HISTORY: the deployed function drifted from
-- 20260717130000-resolve-case-for-inbound.sql through a hand edit in the
-- SQL editor that was never committed. This file captures the production
-- definition verbatim (pg_get_functiondef, 04/08/2026) so a rebuild
-- reproduces what actually runs. It has no schema_migrations record on the
-- server; replaying it against production recreates the identical body, a
-- no-op in effect.
--
-- What the live body adds over the 20260717130000 file:
--   1. Open-case lookup matches by client_id OR customer email, so rows
--      created before linking (null client_id) never spawn a duplicate case.
--   2. When such a row is found, the missing client_id and customer_id are
--      backfilled on the spot.
--   3. Case numbering counts existing cases by either key, keeping serials
--      correct even when historical rows were unlinked.
--
-- The brain_events_external_event_id_key index this function relies on is
-- created by the 20260717130000 file and is unchanged, so it is not
-- repeated here. The stale 3-arg overload is a separate, staging-gated
-- cleanup and is untouched.

CREATE OR REPLACE FUNCTION public.resolve_case_for_inbound(p_email text, p_name text DEFAULT NULL::text, p_nationality text DEFAULT NULL::text, p_message text DEFAULT NULL::text, p_external_event_id text DEFAULT NULL::text, p_provider text DEFAULT 'form'::text, p_subject text DEFAULT NULL::text)
 RETURNS TABLE(out_conversation_id uuid, out_client_id uuid, out_client_code text, out_case_serial_id text, out_case_number integer, out_is_new_customer boolean, out_is_new_case boolean)
 LANGUAGE plpgsql
AS $function$
declare
  v_email text := lower(trim(p_email));
  v_client clients%rowtype;
  v_is_new_customer boolean := false;
  v_is_new_case boolean := false;
  v_next_clt int;
  v_bare_clt text;
  v_conv brain_conversations%rowtype;
  v_next_case_num int;
  v_serial text;
begin
  if v_email is null or v_email = '' then
    raise exception 'resolve_case_for_inbound requires a non-empty email';
  end if;

  -- 1. find or create the customer
  select * into v_client
  from clients
  where lower(trim(email)) = v_email
  limit 1;

  if not found then
    perform pg_advisory_xact_lock(hashtext('clt_number_seq'));

    select coalesce(max((substring(client_code from 'CLT0*([0-9]+)'))::int), 0) + 1
      into v_next_clt
    from clients
    where client_code ~ '^CLT[0-9]';

    insert into clients (client_code, full_name, email, nationality, status, stage)
    values ('CLT' || lpad(v_next_clt::text, 4, '0') || '-XX',
            p_name, v_email, p_nationality, 'Prospect', 'Potential')
    returning * into v_client;

    v_is_new_customer := true;
  end if;

  v_bare_clt := substring(v_client.client_code from '(CLT[0-9]+)');

  -- 2. find an open case for this customer, matched by client_id OR by email
  --    (email is the safety net: older rows or rows created before linking
  --    may have a null client_id, and we must never spawn a duplicate case
  --    for the same person just because the link was missing).
  perform pg_advisory_xact_lock(hashtext('case_seq_' || v_client.id::text));

  select * into v_conv
  from brain_conversations
  where (client_id = v_client.id or lower(trim(customer_email)) = v_email)
    and coalesce(stage, 'Potential') not in ('Complete', 'Lost')
  order by case_number desc nulls last
  limit 1;

  if found then
    -- Backfill the link if it was missing, so future lookups are clean.
    if v_conv.client_id is null then
      update brain_conversations
      set client_id = v_client.id,
          customer_id = coalesce(customer_id, v_client.client_code)
      where id = v_conv.id;
      v_conv.client_id := v_client.id;
    end if;
  else
    -- No open case anywhere for this person: open the next one.
    -- Count existing cases by client_id OR email, so numbering is correct
    -- even if some historical rows were unlinked.
    select coalesce(max(case_number), 0) + 1 into v_next_case_num
    from brain_conversations
    where client_id = v_client.id or lower(trim(customer_email)) = v_email;

    v_serial := 'MGT-CS' || lpad(v_next_case_num::text, 3, '0') || '-' || v_bare_clt;

    insert into brain_conversations
      (customer_id, customer_email, client_id, case_serial_id, case_number,
       subject, stage, conversation_type, status)
    values
      (v_client.client_code, v_email, v_client.id, v_serial, v_next_case_num,
       p_subject, 'Potential', 'lead', 'active')
    returning * into v_conv;

    v_is_new_case := true;
  end if;

  -- 3. optionally log the inbound message (no Brain trigger)
  if p_message is not null and length(trim(p_message)) > 0 then
    insert into brain_events
      (conversation_id, external_event_id, event_type, actor, direction,
       provider, from_email, subject, body_text)
    values
      (v_conv.id,
       coalesce(p_external_event_id,
                'form:' || v_conv.id::text || ':' || extract(epoch from now())::bigint::text),
       'customer_email_received', 'customer', 'inbound',
       p_provider, v_email, p_subject, p_message)
    on conflict (external_event_id) do nothing;
  end if;

  return query select v_conv.id, v_client.id, v_client.client_code,
                      v_conv.case_serial_id, v_conv.case_number,
                      v_is_new_customer, v_is_new_case;
end;
$function$;

notify pgrst, 'reload schema';
