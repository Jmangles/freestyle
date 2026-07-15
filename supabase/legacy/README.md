# Legacy SQL (reference only)

Pre-baseline one-off scripts, kept for history. **Not applied by the CLI** and
not part of the declarative schema — do not run these against local or prod.

- `add_*.sql` / `migrate_*.sql` — incremental changes applied by hand to prod
  before the migration workflow existed. All folded into
  `../migrations/00000000000000_initial_schema.sql`.
- `import_tricks.sql` / `import_tricks2.sql` — hand-maintained trick catalogs,
  each superseding the last. Both retired: the seed now comes from
  `../seed_tricks.sql`, regenerated from prod by `../../scripts/refresh-seed.sh`.

Current source of truth: `../schemas/` (declarative) → `../migrations/`
(generated via `supabase db diff`). See `docs/DEV_SETUP.md`.
