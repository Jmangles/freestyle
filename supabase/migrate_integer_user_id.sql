-- ============================================================
-- Migration: Integer primary key for profiles + integer FK in user_tricks
--
-- 1. Adds int_id (auto-generated integer) to profiles and makes it the PK.
--    The UUID id column is retained as a unique column for auth linkage.
-- 2. Rewires user_tricks.user_id from UUID (auth.users) to integer (profiles).
--
-- Run this in the Supabase SQL Editor against an existing database.
-- ============================================================

-- Step 1: Add integer identity column to profiles
ALTER TABLE profiles
  ADD COLUMN int_id integer GENERATED ALWAYS AS IDENTITY;

-- Step 2: Promote int_id to primary key, demote id to unique
ALTER TABLE profiles DROP CONSTRAINT profiles_pkey;
ALTER TABLE profiles ADD CONSTRAINT profiles_id_unique UNIQUE (id);
ALTER TABLE profiles ADD PRIMARY KEY (int_id);

-- Step 3: Add temporary integer column to user_tricks
ALTER TABLE user_tricks
  ADD COLUMN user_int_id integer;

-- Step 4: Backfill user_int_id by joining on the UUID
UPDATE user_tricks ut
SET user_int_id = p.int_id
FROM profiles p
WHERE p.id = ut.user_id;

-- Step 5: Enforce NOT NULL and add FK to profiles(int_id)
ALTER TABLE user_tricks
  ALTER COLUMN user_int_id SET NOT NULL;

ALTER TABLE user_tricks
  ADD CONSTRAINT user_tricks_user_int_id_fkey
    FOREIGN KEY (user_int_id) REFERENCES profiles(int_id) ON DELETE CASCADE;

-- Step 6: Drop RLS policies that reference the old UUID user_id column
--         (must happen before dropping the column they depend on)
DROP POLICY "user_tricks_select" ON user_tricks;
DROP POLICY "user_tricks_insert" ON user_tricks;
DROP POLICY "user_tricks_update" ON user_tricks;
DROP POLICY "user_tricks_delete" ON user_tricks;

-- Step 7: Drop the composite unique constraint that includes the old UUID column
ALTER TABLE user_tricks
  DROP CONSTRAINT user_tricks_user_id_trick_id_key;

-- Step 8: Drop the old UUID user_id column (also drops its FK to auth.users)
ALTER TABLE user_tricks
  DROP COLUMN user_id;

-- Step 9: Rename the new integer column into place
ALTER TABLE user_tricks
  RENAME COLUMN user_int_id TO user_id;

-- Step 10: Restore the unique constraint using the new integer column
ALTER TABLE user_tricks
  ADD CONSTRAINT user_tricks_user_id_trick_id_key UNIQUE (user_id, trick_id);

-- Step 11: Create new RLS policies using integer comparison via subquery
CREATE POLICY "user_tricks_select" ON user_tricks FOR SELECT
  USING (user_id = (SELECT int_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "user_tricks_insert" ON user_tricks FOR INSERT
  WITH CHECK (user_id = (SELECT int_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "user_tricks_update" ON user_tricks FOR UPDATE
  USING (user_id = (SELECT int_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "user_tricks_delete" ON user_tricks FOR DELETE
  USING (user_id = (SELECT int_id FROM profiles WHERE id = auth.uid()));
