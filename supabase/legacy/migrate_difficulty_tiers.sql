-- Migrate difficulty_tier from 1–10 to the new 1–30 scale.
-- Each old tier N maps to the middle value of its triplet: N * 3 - 1
-- (e.g. old Tier 1 → 2, old Tier 5 → 14, old Tier 10 → 29)
-- TBD (-1) is left unchanged.
--
-- Run this ONCE against the live database, then deploy the updated app.

UPDATE tricks
SET difficulty_tier = (difficulty_tier * 3 - 1)
WHERE difficulty_tier != -1;

-- Update the check constraint to allow the new range.
ALTER TABLE tricks DROP CONSTRAINT tricks_difficulty_tier_check;
ALTER TABLE tricks ADD CONSTRAINT tricks_difficulty_tier_check
  CHECK (difficulty_tier = -1 OR difficulty_tier BETWEEN 1 AND 30);
