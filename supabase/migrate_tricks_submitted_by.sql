-- ============================================================
-- Migration: Switch tricks.submitted_by from UUID to integer
--
-- Rewires submitted_by to reference profiles(int_id) instead of
-- auth.users(id). Run this after migrate_integer_user_id.sql.
-- ============================================================

-- Step 1: Add temporary integer column
ALTER TABLE tricks
  ADD COLUMN submitted_by_int integer;

-- Step 2: Backfill from profiles
UPDATE tricks t
SET submitted_by_int = p.int_id
FROM profiles p
WHERE p.id = t.submitted_by;

-- Step 3: Add FK to profiles(int_id) (nullable — some tricks may have no submitter)
ALTER TABLE tricks
  ADD CONSTRAINT tricks_submitted_by_int_fkey
    FOREIGN KEY (submitted_by_int) REFERENCES profiles(int_id) ON DELETE SET NULL;

-- Step 4: Drop RLS policies that reference the old UUID submitted_by column
DROP POLICY "tricks_read_own" ON tricks;
DROP POLICY "tricks_insert" ON tricks;

-- Step 5: Drop the old UUID submitted_by column (also drops its FK to auth.users)
ALTER TABLE tricks DROP COLUMN submitted_by;

-- Step 6: Rename the new integer column into place
ALTER TABLE tricks RENAME COLUMN submitted_by_int TO submitted_by;

-- Step 7: Recreate RLS policies using integer comparison via subquery
CREATE POLICY "tricks_read_own" ON tricks FOR SELECT
  USING (submitted_by = (SELECT int_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "tricks_insert" ON tricks FOR INSERT
  WITH CHECK (submitted_by = (SELECT int_id FROM profiles WHERE id = auth.uid()));
