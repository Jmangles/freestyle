-- Adds "rarely" as consistency 3 by shifting values >= 3 up by one:
--   old: 0=Never tried, 1=Attempting, 2=Once, 3=Sometimes .. 6=Always
--   new: 0=Never tried, 1=Attempting, 2=Once, 3=Rarely, 4=Sometimes .. 7=Always
--
-- MUST be deployed together with the app release that reads the new scheme
-- (Consistency enum with rarely at index 3, local DB version 5). Older clients
-- read/write the old scheme and will be off by one above "once" until they update.
--
-- Idempotent: the DO block only runs while the old 0..6 check constraint is
-- still in place, so re-running it can never double-shift the data.
--
-- Hand-written rather than generated: `supabase db diff` captures the check
-- constraint change in schemas/user_tricks.sql but never the data shift.

do $$
declare
  old_def text;
begin
  select pg_get_constraintdef(oid) into old_def
  from pg_constraint
  where conrelid = 'public.user_tricks'::regclass
    and conname = 'user_tricks_consistency_check';

  if old_def is null or old_def not like '%<= 6%' then
    raise notice 'consistency rarely migration already applied — nothing to do';
    return;
  end if;

  -- Block concurrent writes so no row is inserted with old semantics
  -- between the shift and the new constraint.
  lock table public.user_tricks in exclusive mode;

  alter table public.user_tricks
    drop constraint user_tricks_consistency_check;

  update public.user_tricks
    set consistency = consistency + 1
    where consistency >= 3;

  alter table public.user_tricks
    add constraint user_tricks_consistency_check
    check (consistency between 0 and 7);
end $$;
