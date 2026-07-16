alter table user_tricks
  add column difficulty_vote smallint check (difficulty_vote between 1 and 30),
  add column leash_position  smallint check (leash_position between 0 and 2),
  add column video_link      text;
