-- User profiles (extends auth.users)
-- flags: bit 0 = can edit tricks
create table profiles (
  int_id   integer generated always as identity primary key,
  id       uuid unique not null references auth.users(id) on delete cascade,
  username text unique,
  flags    smallint not null default 0
);
