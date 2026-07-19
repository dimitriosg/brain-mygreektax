-- resolve_case_for_inbound: the single authority for customer + case identity.
-- Given an inbound sender email, it finds or creates the customer, finds or
-- opens the correct case, optionally logs the inbound message, and returns
-- the MGT-CSxxx-CLTxxxx serial. Race-safe via advisory locks. It never
-- triggers the Brain: drafting is on-demand from the /drafts workspace.
--
-- Depends on brain_conversations_identity_link (client_id, case_serial_id,
-- case_number, stage columns on brain_conversations).
-- Save to supabase/migrations/ after running.

create unique index if not exists brain_events_external_event_id_key
  on brain_events (external_event_id);

create or replace function resolve_case_for_inbound(
  p_email text,
  p_name text default null,
  p_nationality text default null,
  p_message text default null,
  p_external_event_id text default null,
  p_provider text default 'form',
  p_subject text default null
)
returns table (
  out_conversation_id uuid,
  out_client_id uuid,
  out_client_code text,
  out_case_serial_id text,
  out_case_number int,
  out_is_new_customer boolean,
  out_is_new_case boolean
)
language plpgsql
as $$
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

    -- Born as CLT####-XX to match the portal's existing convention:
    -- nationality is set manually on review, which turns -XX into -PT etc.
    insert into clients (client_code, full_name, email, nationality, status, stage)
    values ('CLT' || lpad(v_next_clt::text, 4, '0') || '-XX',
            p_name, v_email, p_nationality, 'Prospect', 'Potential')
    returning * into v_client;

    v_is_new_customer := true;
  end if;

  -- bare CLT number for the case id (strips the -XX / -PT suffix)
  v_bare_clt := substring(v_client.client_code from '(CLT[0-9]+)');

  -- 2. find an open case, or create the next one
  perform pg_advisory_xact_lock(hashtext('case_seq_' || v_client.id::text));

  select * into v_conv
  from brain_conversations
  where client_id = v_client.id
    and coalesce(stage, 'Potential') not in ('Complete', 'Lost')
  order by case_number desc nulls last
  limit 1;

  if not found then
    select coalesce(max(case_number), 0) + 1 into v_next_case_num
    from brain_conversations
    where client_id = v_client.id;

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

  -- 3. optionally log the inbound message onto the case (no Brain trigger)
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
$$;
