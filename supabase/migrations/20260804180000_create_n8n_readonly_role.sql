-- Read-only database role for the n8n automation box.
--
-- HISTORY: this role was created manually in the SQL editor on 04/08/2026
-- while wiring the n8n Morning digest workflow. This file records it so a
-- fresh database rebuild recreates it. It is fully guarded, so replaying it
-- against production is a no-op.
--
-- The password is NOT in this file and never will be. It is set out of band
-- (alter role n8n_readonly with password '...') and lives in Bitwarden.
-- After a fresh rebuild the role cannot log in until that is done.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'n8n_readonly') then
    create role n8n_readonly with login
      nosuperuser nocreatedb nocreaterole noinherit nobypassrls;
  end if;
end
$$;

grant usage on schema public to n8n_readonly;

grant select on public.clients to n8n_readonly;

drop policy if exists n8n_readonly_select_clients on public.clients;

create policy n8n_readonly_select_clients on public.clients
  for select to n8n_readonly using (true);
