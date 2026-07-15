# Dev Setup Notes

## Local Supabase Stack

Test schema / RLS / RPC changes against a local database before running any
SQL against prod. This spins up a full local Supabase stack (Postgres,
GoTrue, PostgREST, Studio) in Docker. Nothing here touches the prod project.

### One-time prerequisites

- Supabase CLI: `brew install supabase/tap/supabase`
- A container runtime, either:
  - Docker Desktop, **or**
  - Podman (start the VM and point Docker's client API at Podman's socket,
    since the Supabase CLI talks to whatever `DOCKER_HOST` points at):
    ```
    podman machine init   # first time only
    podman machine start
    export DOCKER_HOST=unix://$(podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}')
    ```
    Add the `export DOCKER_HOST=...` line to your shell profile so it's set
    in every new terminal. If `supabase start` still can't find a runtime,
    fall back to Docker Desktop or `colima` (`brew install colima && colima
    start`).

### Bringing the DB up

The repo already tracks everything the CLI needs — `supabase/config.toml`
and `supabase/migrations/` — so no `supabase init` is required. Seed data
(the trick catalog) loads from `supabase/import_tricks2.sql`, wired via
`config.toml` → `[db.seed] sql_paths`.

1. `supabase start` — boots the stack and prints the local API URL, DB URL,
   and Studio URL. Defaults:
   - API: `http://127.0.0.1:54321`
   - DB: `postgresql://postgres:postgres@127.0.0.1:54322/postgres`
   - Studio: `http://127.0.0.1:54323`
2. `supabase db reset` — drops and rebuilds the DB from
   `supabase/migrations/` in order, then loads the seed (trick catalog).
   Run this whenever migrations change to get a clean, deterministic DB.

### Running the app against it

```
flutter run -d web-server --web-port=8080 --dart-define=USE_LOCAL_SUPABASE=true
```

`web-server` doesn't auto-open a browser — open `http://localhost:8080`
yourself once it's serving.

Or use the "Flutter (Web server, port 8080, local Supabase)" VS Code launch
config. This flips `SupabaseConfig` (`lib/supabase_config.dart`) over to the
local instance's fixed default URL/anon key — nothing to hand-edit, and
nothing that risks getting committed pointed at the wrong project. Omit the
`--dart-define` to run against prod.

### Schema source of truth

`supabase/schemas/` is the declarative desired state — one file per table
plus `functions.sql` and `rls_and_grants.sql`. Edit those directly;
they're the human-readable source of truth. `supabase/migrations/` is what
the CLI actually applies (`db reset` / `db push`) and is generated from the
schemas by `supabase db diff`. Load order comes from `config.toml` →
`[db.migrations] schema_paths`, not filenames. The older loose `add_*.sql` /
`migrate_*.sql` scripts and the superseded `import_tricks.sql` catalog now live
in `supabase/legacy/` — historical one-offs already folded into the baseline
migration, kept for reference only (never applied). See `supabase/legacy/README.md`.

Adding a schema change:

1. Edit the relevant file(s) in `supabase/schemas/` (or add a new one and
   register it in `config.toml` → `[db.migrations] schema_paths`, in
   dependency order — a table before anything referencing it).
2. `supabase stop` (diff needs the stack down), then `supabase db diff -f
   <name>` to generate the migration into `supabase/migrations/`.
3. `supabase db reset` to verify it applies cleanly locally before it ever
   reaches prod. Commit the schema edit and the generated migration together.

**Prod already has the baseline.** `00000000000000_initial_schema.sql` is a
snapshot of the schema prod already runs — it is only replayed onto fresh
*local* DBs. Never `supabase db push` it to prod (its `create table`s would
conflict). When first linking migrations to the prod project, mark it as
already-applied so only *future* migrations push:
`supabase migration repair --status applied 00000000000000`.

## Flutter Web Should Use Port 8080

The VS Code launch configs and the local Supabase auth redirect URLs
(`config.toml` → `[auth] additional_redirect_urls`) assume Flutter web runs
on port 8080. A random port (the default for `flutter run -d chrome`) can
break auth redirects locally.

```
flutter run -d web-server --web-port=8080
```

The `.vscode/launch.json` "Flutter (Web server, port 8080)" configuration
does this automatically if you run/debug from VS Code instead of the CLI.

## Testing Flutter Web on a Physical Device

Run the dev server bound to all network interfaces so a phone on the same WiFi can reach it:

```powershell
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

Then open `http://<your-pc-local-ip>:8080` in the browser on your phone.
Find your PC's local IP with `ipconfig` — look for the IPv4 address under the WiFi adapter.

### Windows Firewall

Windows blocks inbound connections by default, so you need to temporarily open the port:

```powershell
# Allow inbound connections on port 8080
New-NetFirewallRule -DisplayName "Flutter Web Dev" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow

# Remove the rule when done
Remove-NetFirewallRule -DisplayName "Flutter Web Dev"
```
