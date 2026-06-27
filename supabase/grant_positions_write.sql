-- Grant write permissions on positions to authenticated users.
-- Previously only `select` was granted, causing a permissions error for
-- editors/admins when inserting via the admin panel (RLS was correct but
-- the table-level grant was missing).
grant insert, update, delete on positions to authenticated;
