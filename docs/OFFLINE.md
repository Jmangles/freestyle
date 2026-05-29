# Offline Support

Highliners often use this app in the mountains where cell service is unreliable or nonexistent. The goal is for the core experience — browsing tricks and tracking personal progress — to work fully offline after the user has opened the app at least once with a connection.

## What works offline

| Feature | Offline behavior |
|---|---|
| Trick database | Fully available from local cache |
| Trick detail pages | Fully available from local cache |
| Training video playback | Available if the video was watched at least once (already cached by media_kit) OR if the user has explicitly downloaded it to the device (planned feature — not yet implemented) |
| Training studio annotations | Available from local cache for any trick whose training studio has been opened at least once |
| User progress (consistency) | Read from local cache; writes queued and synced on reconnect |
| Trick filtering and sorting | Works entirely in-memory on cached data |

## What degrades gracefully (blocked when offline)

| Feature | Behavior |
|---|---|
| Submit a trick | Disabled with "you're offline" message |
| Submit a tip | Disabled with "you're offline" message |
| Suggest edits to a trick | Disabled with "you're offline" message |
| Difficulty voting | Disabled with "you're offline" message |
| Video Link | Youtube/Insta links are hidden, training studio button is hidden if the video is not available on the device already either in the cache or downloaded explicitly | 
| Auth (login/register) | Disabled — user must have logged in while online at least once |

User trick data (consistency, landed details) is the one write path that gets queued rather than blocked, since updating your progress mid-session is the most likely thing someone would do offline.

---

## Platform scope

Offline support is **mobile and desktop only**. On web, the normal Supabase fetch path is used without any local cache; `LocalDatabase.init()` is a no-op on web (conditional compilation via `dart.library.html`, matching the existing `web_connection` pattern in this project). Web users rely on browser caching if they lose connectivity.

---

## Approach: sqflite local cache + pending write queue

We use `sqflite` as a local SQLite database that mirrors the data the app needs. Every time data is successfully fetched from Supabase, it is written to the local DB. When the device is offline, the local DB is the source of truth for reads.

### New dependency

```yaml
sqflite: ^2.3.0
```

`path_provider` is already in the project and is used to locate the DB file.

---

## Local database schema

### `tricks` table

Mirrors the Supabase `tricks` table plus the joined position names (denormalized to avoid a join on-device).

```sql
CREATE TABLE tricks (
  id INTEGER PRIMARY KEY,
  given_name TEXT NOT NULL,
  technical_name TEXT,
  difficulty_tier INTEGER NOT NULL,
  date_submitted TEXT NOT NULL,
  date_performed TEXT,
  original_performer TEXT,
  prerequisite_trick_ids BLOB NOT NULL,  -- int32 LE per element; count = bytes.length / 4
  description TEXT,
  tips TEXT,
  video_link TEXT,
  video_start INTEGER,
  video_end INTEGER,
  start_position_id INTEGER,
  end_position_id INTEGER,
  start_position_name TEXT,
  end_position_name TEXT,
  status INTEGER NOT NULL,
  submitted_by INTEGER,
  flags INTEGER NOT NULL DEFAULT 0
)
```

### `positions` table

```sql
CREATE TABLE positions (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL
)
```

### `user_tricks` table

```sql
CREATE TABLE user_tricks (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  trick_id INTEGER NOT NULL,
  consistency INTEGER NOT NULL,
  difficulty_vote INTEGER,
  leash_position INTEGER,
  video_link TEXT,
  video_start INTEGER,
  video_end INTEGER,
  updated_at TEXT NOT NULL,
  UNIQUE(user_id, trick_id)
)
```

### `trick_annotations` table

```sql
CREATE TABLE trick_annotations (
  id INTEGER PRIMARY KEY,
  trick_id INTEGER NOT NULL,
  start_ms INTEGER NOT NULL,
  end_ms INTEGER NOT NULL,
  text TEXT NOT NULL,
  language TEXT NOT NULL
)
```

Cached on successful `getForTrick(trickId, language)`. Reads return rows matching `(trick_id, language)`. Annotation mutations (create/update/delete, editor-only) are blocked offline like other write operations.

### `pending_writes` table

Queues offline writes for sync when connectivity is restored.

```sql
CREATE TABLE pending_writes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  table_name TEXT NOT NULL,        -- e.g. "user_tricks"
  operation TEXT NOT NULL,         -- "upsert"
  payload TEXT NOT NULL,           -- JSON of the fields to write
  local_snapshot_at TEXT NOT NULL, -- updated_at value from local DB at time of write
  created_at TEXT NOT NULL,
  retry_count INTEGER NOT NULL DEFAULT 0
)
```

Entries that fail during a flush increment `retry_count`. Once `retry_count` reaches **5** the entry is dropped and logged (but not surfaced to the user, since at that point it is almost certainly a permanent error such as an RLS rejection or a malformed payload, not a transient network issue).

### `meta` table

Tracks cache freshness.

```sql
CREATE TABLE meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
-- keys: "tricks_last_synced", "positions_last_synced", "user_tricks_last_synced"
```

---

## Data flow

### Reads

```
app requests data
       │
       ▼
  online?
  ├─ YES → fetch from Supabase → write to local DB → return to UI
  └─ NO  → read from local DB → return to UI
```

### Writes (user_tricks only)

```
user updates consistency / landed details
       │
       ▼
  online?
  ├─ YES → write to Supabase → update local DB
  └─ NO  → write to local DB → add row to pending_writes
       │
       ▼
  connectivity restored
       │
       ▼
  flush pending_writes → execute each against Supabase → clear queue
```

### Conflict resolution

The `pending_writes` queue is ordered by `created_at`. Before flushing, entries for the same `(table_name, trick_id)` are collapsed to the latest one — only the final state matters, so intermediate writes are discarded.

`user_tricks` uses `upsert` with `ON CONFLICT(user_id, trick_id)`. Because RLS ensures only the user writes their own rows, the only genuine conflict scenario is multi-device: the user updated the same trick on another device while this device was offline.

`local_snapshot_at` enables detection of and resolution of that case: before flushing a pending write, the flush process reads the server's current `updated_at` for that row.

- If the server's `updated_at` ≤ `local_snapshot_at`, no conflict — proceed with the upsert normally.
- If the server's `updated_at` > `local_snapshot_at`, the other device wrote more recently. The pending write is **discarded** and the server's row is fetched into the local cache instead. The newer change wins.

No user-facing conflict UI is needed. The "most recent change by wall-clock time wins" rule is simple and matches user expectation (if you updated on your phone after you used your tablet, the phone's value is what you'd expect to see).

---

## Implementation plan

### 1. `LocalDatabase` service (`lib/services/local_database.dart`)

A singleton that owns the sqflite connection, handles schema creation/migration, and exposes typed read/write methods for each table. This is the only class that touches sqflite directly.

**Schema versioning:** the DB is opened with an explicit version integer. On a version bump the entire DB is dropped and recreated (`onUpgrade` calls `onDrop` then `onCreate`). Because all local data is a cache of Supabase state (and `pending_writes` is flushed before any upgrade path could be hit during a normal app session), a full wipe is acceptable — the DB repopulates from Supabase on the next online launch.

### 2. Cache layer in existing services

`TricksService` and `UserTricksService` get a connectivity check at the top of each fetch method:

- **Online:** fetch from Supabase as today, then call `LocalDatabase.cacheTricks(...)` / `LocalDatabase.cacheUserTricks(...)` in the background.
- **Offline:** call `LocalDatabase.getTricks()` / `LocalDatabase.getUserTricks()` directly.

No changes to the UI layer or routing are needed.

### 3. `PendingWritesQueue` (part of `LocalDatabase`)

`UserTricksService.setConsistency` and `setLandedDetails` enqueue a pending write when offline. The queue is flushed in three situations:

- **App start (cold launch):** if the device is already online when the app launches, the queue is flushed immediately after `LocalDatabase.init()` completes. This is the critical path for test 4.5 (kill app with queued writes, relaunch while online).
- **App resume:** each time the app returns to the foreground.
- **Connectivity restored:** via `connectivity_plus` onChange events.

The flush is **strictly serial**: rows are processed one at a time in `created_at` order (not concurrently).

### 4. Offline banner and connectivity detection

Connectivity is determined by two independent signals:

- **`connectivity_plus`** drives the offline banner: when it reports no connection the banner appears immediately without a network round-trip.
- **Service-layer fallback**: each service method wraps its Supabase call in try/catch; a `SocketException` or `ClientException` triggers the same local-DB fallback regardless of what `connectivity_plus` reports. This handles captive portals and weak-signal scenarios where the OS reports a connection but Supabase is unreachable.

The banner is shown in the app shell (`MainShell`) via a `StreamBuilder` on `Connectivity().onConnectivityChanged`.

### 5. Cache freshness

Tricks, positions, and user_tricks data are considered stale after 24 hours. On app start with connectivity, if `tricks_last_synced`, `positions_last_synced`, or `user_tricks_last_synced` is older than 24 hours (or missing), a background refresh runs for that dataset. This keeps the local DB current without blocking the UI.

---

## Notes on specific queries

### `getTricksRequiring(trickId)` offline

`prerequisite_trick_ids` is stored as a BLOB (int32 LE per element; count = bytes.length / 4) and cannot be searched with a SQL `WHERE` clause. When offline, `getTricksRequiring` loads all cached tricks and filters in Dart: `tricks.where((t) => t.prerequisiteTrickIds.contains(trickId))`. For a dataset of this size this is fast and requires no additional index.

All other uses of `prerequisiteTrickIds` in the app are already in-memory Dart operations on already-fetched lists, so no other query paths are affected.

---

## What stays the same

- Auth: Supabase's Flutter SDK already persists the session token locally. If the user was logged in when they last had connectivity, `AuthService.isLoggedIn` returns true offline.
- Video caching: already handled by media_kit's file cache. No changes needed.
- Filtering/sorting: already done in-memory on the fetched list, so it works on cached data without any changes.

---

## Testing criteria

All manual tests assume a physical or emulated mobile device unless noted. "Go offline" means enable airplane mode.

### Overall success criterion

A logged-in user who has opened the app at least once with connectivity can: go offline, open the app, browse all tricks, see their personal progress, and update their consistency for any trick. When they reconnect, every consistency change they made offline is reflected in Supabase without data loss or duplication.

---

### 1. LocalDatabase — schema and BLOB encoding

| # | Scenario | Pass condition |
|---|---|---|
| 1.1 | Fresh install, launch with connectivity | `highline.db` is created; all six tables exist with correct column names |
| 1.2 | Encode `[]` → BLOB → decode | Returns `[]` |
| 1.3 | Encode `[1, 42, 1000]` → BLOB → decode | Returns `[1, 42, 1000]` in the same order |
| 1.4 | Encode a list of 300 IDs → decode | Returns identical list (validates uint16 header capacity) |
| 1.5 | Launch app a second time with existing DB | Tables are not re-created; existing rows are preserved |

---

### 2. Cache layer — tricks and positions

| # | Scenario | Pass condition |
|---|---|---|
| 2.1 | Launch online, then go offline and navigate to the trick list | Trick list loads with the same tricks as the online session; no error screen |
| 2.2 | Go offline and open a trick detail page | Trick name, description, difficulty, prerequisites, and positions all display correctly |
| 2.3 | Go offline and open the trick progression screen | Progression graph renders; prerequisite relationships are correct |
| 2.4 | Go offline and open the profile screen | "Ready to try" and "in progress" categories populate correctly from cached tricks and user_tricks |
| 2.5 | Apply a filter or sort while offline | Results are correct and match what would be shown online |
| 2.6 | Launch for the first time with no connectivity (never cached) | App shows an empty state or appropriate message — does not crash |

---

### 3. Cache layer — user tricks

| # | Scenario | Pass condition |
|---|---|---|
| 3.1 | Set consistency for several tricks online, then go offline | Previously-set consistency values appear correctly on the trick list and detail pages |
| 3.2 | Go offline as a logged-out user | User progress sections show empty state; no crash or error |

---

### 4. Pending writes queue

| # | Scenario | Pass condition |
|---|---|---|
| 4.1 | Go offline, set consistency on a trick, reconnect | Supabase `user_tricks` row reflects the new consistency value; `pending_writes` table is empty |
| 4.2 | Go offline, set consistency on the same trick five times in a row, reconnect | Exactly one Supabase write is made (intermediate values collapsed); final consistency value is correct |
| 4.3 | Go offline, set consistency (`setConsistency`), then immediately set landed details (`setLandedDetails`) for the same trick, reconnect | Both are applied in a single upsert; Supabase row reflects both consistency and landed details |
| 4.4 | Go offline, update consistency for three different tricks, reconnect | All three tricks are updated in Supabase; `pending_writes` is empty |
| 4.5 | Kill the app while offline with queued writes, relaunch online | Queued writes are flushed immediately on cold launch (not just on resume); `pending_writes` is empty after launch |
| 4.6 | Supabase write fails during flush (e.g. transient error) | Failed entry increments `retry_count` and stays in `pending_writes`; subsequent entries are still attempted; no permanent data loss |
| 4.7 | A pending write's `retry_count` reaches 5 | Entry is dropped and logged; remaining queued entries continue to flush normally |
| 4.8 | Go offline on device A, update a trick, go online on device B and update the same trick, reconnect device A | Device A discards its pending write and pulls the server's newer value; Supabase row reflects device B's change |

---

### 5. Offline banner

| # | Scenario | Pass condition |
|---|---|---|
| 5.1 | Enable airplane mode while the app is open | Offline banner appears within ~1 second |
| 5.2 | Disable airplane mode while the banner is showing | Banner disappears; normal data fetching resumes |
| 5.3 | Launch app in airplane mode | Banner is present immediately on the first screen |
| 5.4 | Navigate between screens while offline | Banner persists across navigation; does not flash or disappear between routes |

---

### 6. Blocked actions while offline

| # | Scenario | Pass condition |
|---|---|---|
| 6.1 | Open trick detail and attempt to submit a tip while offline | "You're offline" message shown; submission does not proceed |
| 6.2 | Open trick detail and attempt to vote on difficulty while offline | Vote control is disabled or shows offline message |
| 6.3 | Attempt to suggest edits to a trick while offline | Edit flow is blocked with offline message |
| 6.4 | Open trick detail for a trick with a YouTube link while offline | YouTube link is hidden; training studio button is hidden if no local video exists |

---

### 7. Annotations

| # | Scenario | Pass condition |
|---|---|---|
| 7.1 | Open training studio for a trick online (annotations visible), then go offline and reopen it | Same annotations appear in the correct positions |
| 7.2 | Go offline and open training studio for a trick never previously opened | Annotation overlay is empty; video still plays if cached; no crash |

---

### 8. Cache freshness

| # | Scenario | Pass condition |
|---|---|---|
| 8.1 | `tricks_last_synced` is missing (fresh install with connectivity) | Tricks are fetched from Supabase on first launch and timestamp is written to `meta` |
| 8.2 | `tricks_last_synced` is less than 24 hours old | No background refresh is triggered on app start |
| 8.3 | `tricks_last_synced` is more than 24 hours old and device is online | Background refresh runs; `tricks_last_synced` is updated; UI is not blocked during the refresh |
| 8.3a | `positions_last_synced` is more than 24 hours old and device is online | Background positions refresh runs; `positions_last_synced` is updated |
| 8.4 | `user_tricks_last_synced` is more than 24 hours old and device is online | Background user_tricks refresh runs; `user_tricks_last_synced` is updated; pending writes are flushed before the refresh so they are not overwritten |

---

### 9. Web platform

| # | Scenario | Pass condition |
|---|---|---|
| 9.1 | Open the web build and browse tricks | All existing functionality works as before; no sqflite errors in the console |
| 9.2 | Log in and update consistency on the web build | Supabase write goes through directly; no local DB code is invoked |

---

## Human-verified checklist

Run through these manually on a physical or emulated device as each system is implemented. Cross-reference the numbered test cases above for exact pass conditions.

**Cache layer**
- [ ] Trick list loads correctly after going offline (2.1)
- [ ] Trick detail page — all fields correct offline (2.2)
- [ ] Trick progression screen renders offline (2.3)
- [ ] Profile screen categories correct offline (2.4)
- [ ] Filters and sorting work offline (2.5)
- [ ] First launch with no connectivity — no crash, shows empty state (2.6)
- [ ] Consistency values appear correctly after going offline (3.1)
- [ ] Logged-out user offline — empty state, no crash (3.2)

**Pending writes**
- [ ] Single consistency change syncs on reconnect (4.1)
- [ ] Rapid consecutive changes to same trick — only final value written (4.2)
- [ ] `setConsistency` then `setLandedDetails` offline, both apply correctly on reconnect (4.3)
- [ ] Changes to three different tricks all sync (4.4)
- [ ] Kill app with queued writes, relaunch online — flushed immediately on cold launch (4.5)
- [ ] Transient flush failure — entry stays queued, retry_count increments, others still attempted (4.6)
- [ ] Entry with retry_count 5 is dropped; flush continues (4.7)
- [ ] Multi-device conflict — newer server timestamp wins, local pending write discarded (4.8)

**Offline banner**
- [ ] Banner appears within ~1 second of enabling airplane mode (5.1)
- [ ] Banner disappears when connectivity restored (5.2)
- [ ] Banner present immediately on launch in airplane mode (5.3)
- [ ] Banner persists across screen navigation (5.4)

**Blocked actions**
- [ ] Submit tip blocked offline (6.1)
- [ ] Difficulty vote blocked offline (6.2)
- [ ] Suggest edits blocked offline (6.3)
- [ ] YouTube link and training studio button hidden offline when no local video (6.4)

**Annotations**
- [ ] Annotations visible offline for a trick whose training studio was previously opened (7.1)
- [ ] Training studio for never-opened trick offline — empty annotations, no crash (7.2)

**Cache freshness**
- [ ] Background tricks refresh triggers and completes when cache is stale (8.3)
- [ ] Background positions refresh triggers and completes when cache is stale (8.3a)
- [ ] Background user_tricks refresh triggers after pending writes are flushed (8.4)

**Web**
- [ ] Existing functionality unchanged on web build (9.1)
- [ ] Consistency update on web goes directly to Supabase (9.2)

---

## Mocking strategy

### What can and cannot be mocked given the current architecture

All service classes in this project use static methods that call `Supabase.instance.client` directly — a global singleton. This means the Supabase layer cannot be swapped out in tests without either introducing a DI layer (out of scope) or running a real Supabase instance. The two practical automation surfaces are `LocalDatabase` (isolatable via an in-memory SQLite factory) and `connectivity_plus` (has a platform-level mock). Everything else in the test matrix is manual.

---

### `LocalDatabase` — automated with `sqflite_common_ffi`

**What it covers:** test groups 1 (schema and BLOB encoding) and the queue logic in group 4 (collapse, ordering, persistence).

`sqflite_common_ffi` provides `databaseFactoryFfi`, a pure-Dart FFI SQLite implementation that runs in the Dart VM without a device. Combined with `inMemoryDatabasePath`, each test gets a fresh database with no file system side effects.

**Required dev dependency:**

```yaml
dev_dependencies:
  sqflite_common_ffi: ^2.3.3
```

**Required `LocalDatabase` design:** `LocalDatabase.init()` must accept an optional `DatabaseFactory` parameter that defaults to the normal sqflite factory. In tests, pass `databaseFactoryFfi` instead. Nothing else in the app needs to change.

```dart
// production
await LocalDatabase.init();

// test
await LocalDatabase.init(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
```

**Tests this enables (fully automated, no device):**
- 1.2, 1.3, 1.4 — BLOB encode/decode round-trips
- 1.1, 1.5 — schema creation and idempotency
- 4.2 — collapse of duplicate pending writes for the same trick
- 4.5 — queue persistence across re-open (open the same in-memory DB twice in one test)
- Read/write roundtrip for each table (tricks, positions, user_tricks, trick_annotations, meta)

Test files live in `test/services/local_database_test.dart`.

---

### `connectivity_plus` — automated with `MockConnectivityPlatform`

**What it covers:** test group 5 (offline banner show/hide) as widget tests.

`connectivity_plus` exposes `ConnectivityPlatform.instance`, a global that can be replaced before a test runs. Swap it for a custom implementation that returns a controlled `Stream<List<ConnectivityResult>>`, then pump the widget tree and assert banner visibility.

No additional dependency is needed — `connectivity_plus` ships this interface.

```dart
// In test setUp:
ConnectivityPlatform.instance = FakeConnectivity();

// FakeConnectivity exposes a StreamController you push results into:
fakeConnectivity.controller.add([ConnectivityResult.none]); // go offline
fakeConnectivity.controller.add([ConnectivityResult.wifi]); // come back online
```

**Tests this enables (widget tests, no device):**
- 5.1 — banner appears when connectivity stream emits `none`
- 5.2 — banner disappears when stream emits `wifi`
- 5.3 — banner present on first frame when initial result is `none`

---

### Supabase — local instance for integration testing

**What it covers:** test groups 2, 3, 4.1, 4.3, 4.4, 4.6, 7, 8 — anything that requires real Supabase reads and writes.

The Supabase CLI (`supabase start`) spins up a local Postgres + PostgREST + Auth stack on `http://localhost:54321`. The app can be pointed at it by changing `SupabaseConfig.url` and `SupabaseConfig.anonKey` to the local values (printed by `supabase start`). The local instance has the full schema applied from `supabase/schema.sql`.

This is not wired into automated CI — it's a developer tool for thorough pre-ship testing of the service + cache integration without touching the production database. Seed the local instance with a few tricks and a test user, then run through the relevant test cases on a simulator pointed at `localhost`.

**Setup:**
```sh
# one-time
npm install -g supabase   # or brew install supabase/tap/supabase
supabase start            # from the project root

# prints:
#   API URL: http://localhost:54321
#   anon key: eyJ...
```

---

### Summary — which tests are automatable

| Group | Manual | Automated (unit/widget) | Requires local Supabase |
|---|---|---|---|
| 1 — LocalDatabase schema + BLOB | | ✓ `sqflite_common_ffi` | |
| 2 — Tricks cache | ✓ primary | | ✓ integration |
| 3 — User tricks cache | ✓ primary | | ✓ integration |
| 4 — Pending writes queue | ✓ primary | ✓ queue logic only | ✓ flush integration |
| 5 — Offline banner | | ✓ widget test | |
| 6 — Blocked actions | ✓ | | |
| 7 — Annotations | ✓ primary | | ✓ integration |
| 8 — Cache freshness | ✓ primary | ✓ `meta` table logic | |
| 9 — Web | ✓ | | |
