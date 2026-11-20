# Database changes

For every database schema change, update the declarative definitions in
`supabase/schemas/` and the `schema_paths` load order in `supabase/config.toml`
when needed. Include the corresponding migration; declarative schemas and
migrations must describe the same desired database state.
