-- Chat history is not a system of record and it quotes client detail freely,
-- so it should not accumulate forever. Trim on insert rather than on a
-- schedule, so retention cannot silently stop working when a cron does.
-- 400 rows per session is roughly 200 exchanges, far more than the 20 turn
-- context window the agent actually reads.

create or replace function public.mgt_assistant_memory_trim()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.mgt_assistant_memory m
  where m.session_id = new.session_id
    and m.id <= (
      select max(id) - 400
      from public.mgt_assistant_memory
      where session_id = new.session_id
    );
  return null;
end;
$$;

drop trigger if exists mgt_assistant_memory_trim_after_insert on public.mgt_assistant_memory;
create trigger mgt_assistant_memory_trim_after_insert
after insert on public.mgt_assistant_memory
for each row execute function public.mgt_assistant_memory_trim();
