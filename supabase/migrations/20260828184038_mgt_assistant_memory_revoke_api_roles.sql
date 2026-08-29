-- New tables in public inherit blanket grants to anon and authenticated from
-- Supabase default privileges. RLS with no policies already blocks them, but
-- the grants themselves are wider than anything else in this schema. Remove.

revoke all on public.mgt_assistant_memory from anon, authenticated;
revoke all on sequence public.mgt_assistant_memory_id_seq from anon, authenticated;

notify pgrst, 'reload schema';
