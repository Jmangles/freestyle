# Legacy trick-id mapping

When `highline-freestyle.com` is repointed from the old app to this one, we want
old users to keep their tracked progress. The old app stored everything locally
in the browser (IndexedDB via Dexie), keyed by **its own** trick ids. This app
has its own `generated always as identity` ids. Nothing links the two id spaces,
so recovered progress has to be translated old-id → new-id. These files are that
translation table.

## The deployed legacy app

The live site is served from GitHub Pages, CNAME `www.highline-freestyle.com`,
**source branch `gh-pages`** (a build of branch **`main`** — a React 17 + Dexie
app). The later `rewrite` branch (a Vue rewrite with a different id scheme) was
**never deployed**, so it is *not* the source here.

| | Legacy app (`main`) | This app |
|---|---|---|
| storage | IndexedDB (Dexie), React 17 | Postgres / Supabase |
| catalog | `src/predefinedTricksCombos.js` (CSV in a template literal) | `supabase/seed_tricks.sql` |
| trick id | `predefinedTricks` id, **10000+** | DB identity id, unrelated |
| user progress | Dexie `userTricks` table, keyed by the same id | `user_tricks` etc. |
| difficulty | `difficultyLevel` 1–10 (`999` = unset) | `difficulty_tier` 1–30 |
| positions | strings (`SOFA`, `KOREAN`) | FK to `positions` |
| name fields | `technicalName` + `alias` | `technical_name` + `given_name` |

The **names** line up (this app's catalog was derived from `main`), even though
the ids don't — that's what the mapping is built on.

Counts at generation time: 262 legacy predefined tricks (ids 10000–10284),
399 new tricks.

## How the mapping was built

`tools/build_legacy_trick_map.py` matches on normalized trick names
(`technicalName`/`alias` ↔ `technical_name`/`given_name`), in tiers:

- **`exact`** – normalized names match directly.
- **`rule`** – match after collapsing systematic renames: a trailing ` Flip`,
  and abbreviation swaps (`DDK` ↔ `Double Drop Knee`, `NH` ↔ `No Hook`,
  `OH` ↔ `One Hand`).
- **`confirmed`** – a human decision from `overrides.csv` (see below).
- Everything left over is scored with a fuzzy string ratio and split into a
  **review** list (≥ 0.80) and a **no-equivalent** list.

For the review list a `recommendation` is computed: `reject` when the two names
differ on a *discriminating* token (rotation like 180/360/540, side BS/FS,
start/end position, roll/flip direction), `suggest` when they differ only by
filler. Fuzzy similarity is a false-match magnet — `Shark Bite`→`Rocket Line
Bite` scores 0.95 — so nothing in the review list is applied without human
confirmation.

## Files

- **`trick_id_map.csv`** (252) – confident matches, safe to apply as-is.
  `legacy_id,new_id,tier,legacy_name,new_name`.
- **`trick_id_map_review.csv`** (0) – fuzzy candidates a human who knows the
  tricks still has to judge. Currently empty: every legacy trick is either
  mapped or explicitly recorded as having no equivalent. Record any decision in
  `overrides.csv`, not here — this file is regenerated.
- **`trick_id_map_none.csv`** (10) – legacy tricks with no equivalent in the new
  catalog: `Chest to Feet`, `Soup to Feet`, `Chest Bounce`, `Soup Bounce`,
  `Back Bounce`, `Belly Bounce`, `Double Drop Knee Almighty`, plus the three
  superseded bounces below. Progress on these can't be mapped; decide whether
  to drop it silently or surface it to the user.
- **`overrides.csv`** – durable human decisions, read back by the generator and
  applied over the automatic tiers. `legacy_id,new_id,note`: a filled `new_id`
  forces a confident (`confirmed`) match; a blank `new_id` forces
  "no equivalent". This is the one file you hand-edit.

Every one of the 262 legacy tricks lands in exactly one of the map / review /
none files, and no two legacy tricks map to the same new id.

## Bounces: legacy pairs vs one new trick

The legacy catalog split a bounce into an entry (`X Bounce`, STAND→X) and an
exit (`X to Feet`, X→STAND). This app has a single round-trip trick per
position (`Korean Bounce` 305, `Sit Bounce` 498, `Sofa Bounce` 410, all
STAND→STAND / EXPO→EXPO). Only the exit is mapped onto it; the legacy entry is
dropped, keeping the map one-to-one on `new_id`. Progress a user tracked on
`Korean/Sit/Sofa Bounce` but not on the matching `to Feet` is lost — accepted
trade-off. `Chest` and `Soup` have no bounce trick here at all, so both halves
stay unmapped.
Custom tricks a user authored themselves (Dexie `userTricks` with an
auto-increment id, not in the predefined catalog) are out of scope — they have
no counterpart here and would need to be re-created as new tricks if kept.

## The legacy Dexie database

From `src/services/db.js` on branch `main`:

- database name **`db`** (`new Dexie("db")`), current schema version **8**
- tables: `versions`, `predefinedTricks`, `userTricks`, `predefinedCombos`,
  `userCombos`

Progress lives in **`userTricks`**, keyed by the same id as the predefined
trick it belongs to. Two things make it awkward to read:

- **rows are sparse.** The v7 upgrade deletes every attribute that equals the
  predefined trick's value, so a `userTricks` row holds only what the user
  changed. Read `stickFrequency` from the `userTricks` row and treat a missing
  field as "not tracked" — the old app reconstructs a trick as
  `{...predefinedTrick, ...userTrick}`.
- **`deleted: true`** marks a trick the user hid; skip those rows.

Ids ≥ 10000 are predefined tricks (mappable via `trick_id_map.csv`); the
`++id` auto-increment gives user-authored tricks small ids, so the two are
easy to tell apart. `boostSkill` and both combo tables have no counterpart in
this app.

A browser that hasn't loaded the old app in a long time can sit at an older
schema version, where `stickFrequency` still holds pre-v5 values. The importer
reads the store raw — opening without a version, so no upgrade is triggered and
the legacy data is never rewritten — and applies the v5 shift (5 and 6 move up
by one) itself when the database reports a Dexie version below 5. This is the
legacy Dexie version, unrelated to `LocalDatabase._kVersion` in this app.

Dexie does not use its own version number as the IndexedDB version: it opens at
`Math.round(verno * 10)` (`src/classes/dexie/dexie-open.ts`) and divides by ten
on the way back out. So `IDBDatabase.version` reads **80** for a current legacy
database and **40** for a pre-v5 one, and the importer must divide before
comparing — testing `version < 5` against the raw native number matches nothing.

## Consistency values

Legacy `stickFrequency` is an index into `stickFrequencies` in
`src/services/enums.js` (8 values). This app's `Consistency` enum also has 8
since migration `20260803120000_consistency_rarely.sql` inserted `rarely` at
index 3, so the two line up one-to-one.

| legacy | name | → new | name |
|---|---|---|---|
| 0 | Never tried | 0 | neverTried |
| 1 | Work in progress | 1 | attempting |
| 2 | Once | 2 | once |
| 3 | Rarely | 3 | rarely |
| 4 | Sometimes | 4 | sometimes |
| 5 | Often | 5 | often |
| 6 | Generally | 6 | generally |
| 7 | Always | 7 | always |

So: identity. `user_tricks.consistency` is `check (consistency between 0 and 7)`,
so any out-of-range legacy value must be clamped, not inserted.

Before `rarely` existed the mapping folded legacy `Rarely` into `Sometimes` and
subtracted one from everything above it. Adding a `Consistency` value silently
invalidates this table — `legacy_import_test.dart` asserts the mapping covers
every enum value so that a future addition fails the build instead.

## Regenerating

```
# clone the DEPLOYED legacy branch
gh repo clone bastislack/highline-freestyle /tmp/legacy-main -- --depth 1 --branch main
python3 tools/build_legacy_trick_map.py \
    /tmp/legacy-main/src/predefinedTricksCombos.js \
    supabase/seed_tricks.sql \
    docs/legacy-migration
```

`seed_tricks.sql` is regenerated from prod by `scripts/refresh-seed.sh`; rerun
the mapping after the catalog changes so new tricks pick up matches.

## The importer

IndexedDB survives a DNS repoint because the browser keys storage by **origin
string**, not by which server answers — so the new app, served at the same
`www.highline-freestyle.com` origin, reads the old app's Dexie database
directly. `lib/services/legacy_import_service_web.dart` does that (no-op stub
on every other platform, since the legacy app was browser-only):

1. **Gate** – only on a `highline-freestyle.com` host, and only while the
   `legacy_import_done` pref is unset.
2. **Scan** – open IndexedDB `db` without a version (so no Dexie upgrade is
   triggered), read `userTricks`, skip `deleted` rows and `stickFrequency` 0,
   split the rest into importable / untransferable / custom-trick counts.
   Opening a database that doesn't exist creates an empty one; that gets
   deleted again right away.
3. **Prompt** – `HomeScreen` shows a dialog once (`legacy_import_prompt_seen`),
   then a dismissible banner; `ProfileScreen` keeps a permanent card until the
   import has run. Signed-out users are sent to `/login` and the import resumes
   automatically once the auth state flips.
4. **Import** – translate ids through the bundled `assets/legacy/trick_id_map.json`,
   map `stickFrequency` to `Consistency`, read the profile's existing
   `user_tricks` and write only where the legacy value is **higher**, in
   upserts of 200 rows. Difficulty is not imported: this app takes difficulty
   from the catalog, and legacy per-user difficulty edits have no counterpart.
   `boostSkill`, both combo tables, and per-user catalog edits are dropped.
5. **Finish** – set `legacy_import_done`, report counts, leave the legacy
   database in place so a bad import stays recoverable.

The JSON asset is written by the same generator that writes the CSVs; a test
(`test/models/legacy_import_test.dart`) asserts the two stay in sync.

Caveats: only same-origin browser-tab users are covered (not native/installed
builds, different sandbox); non-persisted IndexedDB is evictable (Safari/ITP
~7 days, storage pressure), so treat it as best-effort. Keep the
`www.highline-freestyle.com` origin serving the new app through a grace window
before any redirect — redirecting immediately strips users of the origin that
holds their data. Note the live CNAME is the **`www.`** host; make sure the new
app is reachable there (not only the apex) or the stored data is unreachable.
