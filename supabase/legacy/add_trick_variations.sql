alter table tricks
  add column base_trick_ids integer[] not null default '{}';

alter table trick_suggestions
  add column base_trick_ids integer[];
