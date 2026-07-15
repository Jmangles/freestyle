-- Adds "never tried" as consistency 0 by shifting all existing values +1:
--   old: 0=Attempting .. 5=Always   →   new: 0=Never tried, 1=Attempting .. 6=Always
--
-- MUST be deployed together with the app release that reads the new scheme
-- (Consistency enum with neverTried at index 0, local DB version 4). Older
-- clients read/write the old scheme and will be off by one until they update.
--
-- Idempotent: the DO block only runs while the old 0..5 check constraint is
-- still in place, so re-running it can never double-shift the data.

do $$
declare
  old_def text;
begin
  select pg_get_constraintdef(oid) into old_def
  from pg_constraint
  where conrelid = 'public.user_tricks'::regclass
    and conname = 'user_tricks_consistency_check';

  if old_def is null or old_def not like '%<= 5%' then
    raise notice 'consistency migration already applied — nothing to do';
    return;
  end if;

  -- Block concurrent writes so no row is inserted with old semantics
  -- between the shift and the new constraint.
  lock table public.user_tricks in exclusive mode;

  alter table public.user_tricks
    drop constraint user_tricks_consistency_check;

  update public.user_tricks
    set consistency = consistency + 1;

  -- default 0 now means "never tried" instead of "attempting" — the app
  -- always writes consistency explicitly, so the default is only a safety net.
  alter table public.user_tricks
    add constraint user_tricks_consistency_check
    check (consistency between 0 and 6);
end $$;
