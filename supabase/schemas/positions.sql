-- Positions (e.g. Standing, Hanging, Sitting)
create table positions (
  id   smallint generated always as identity primary key,
  name text not null unique
);
