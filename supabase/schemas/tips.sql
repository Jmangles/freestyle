-- Tips: community-submitted general highlining tips (not trick-specific)
-- status: false = pending, true = approved
-- type: 0 = general, 1 = rigging, 2 = health
create table tips (
  id              integer generated always as identity primary key,
  title           text not null,
  header          text,
  body            text not null,
  status          boolean not null default false,
  type            smallint not null default 0 check (type between 0 and 2),
  submitted_on    date not null default current_date,
  submitted_by    integer references profiles(int_id) on delete set null,
  approved_on     date,
  approved_by     integer references profiles(int_id) on delete set null,
  last_updated    date,
  last_updated_by integer references profiles(int_id) on delete set null
);
