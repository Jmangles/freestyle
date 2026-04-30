alter table tricks
  add column video_start smallint,
  add column video_end   smallint;

alter table user_tricks
  add column video_start smallint,
  add column video_end   smallint;
