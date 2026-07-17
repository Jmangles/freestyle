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

- **`trick_id_map.csv`** (250) – confident matches, safe to apply as-is.
  `legacy_id,new_id,tier,legacy_name,new_name`.
- **`trick_id_map_review.csv`** (6) – fuzzy candidates a human who knows the
  tricks still has to judge. All 6 currently carry a `reject` recommendation
  (the suggested match is a coincidence or a genuinely different trick, e.g.
  `Korean to Feet` ≠ `Korean 720 to feet`, `NH Backflip` ≠ `Back Roll from Feet
  to Feet`). Record any decision in `overrides.csv`, not here — this file is
  regenerated.
- **`trick_id_map_none.csv`** (6) – legacy tricks with no equivalent in the new
  catalog (`Chest to Feet`, `Soup to Feet`, `Sit to Feet`, `Back Bounce`,
  `Belly Bounce`, `Double Drop Knee Almighty`). Progress on these can't be
  mapped; decide whether to drop it silently or surface it to the user.
- **`overrides.csv`** – durable human decisions, read back by the generator and
  applied over the automatic tiers. `legacy_id,new_id,note`: a filled `new_id`
  forces a confident (`confirmed`) match; a blank `new_id` forces
  "no equivalent". This is the one file you hand-edit.

Every one of the 262 legacy tricks lands in exactly one of the map / review /
none files.
Custom tricks a user authored themselves (Dexie `userTricks` with an
auto-increment id, not in the predefined catalog) are out of scope — they have
no counterpart here and would need to be re-created as new tricks if kept.

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

## How recovery consumes this

IndexedDB survives a DNS repoint because the browser keys storage by **origin
string**, not by which server answers — so the new app, served at the same
`www.highline-freestyle.com` origin, can read the old app's Dexie database. A
one-time importer would:

1. open the legacy Dexie DB, read the user's `userTricks` rows (their tracked
   progress: `stickFrequency`, `boostSkill`, etc.), keyed by predefined id;
2. translate each legacy id via `trick_id_map.csv` (+ any confirmed review
   rows); skip / report ids in `trick_id_map_none.csv` and custom user tricks;
3. write the translated progress into this app's tables for the signed-in
   profile, then mark the import done.

Caveats: only same-origin browser-tab users are covered (not native/installed
builds, different sandbox); non-persisted IndexedDB is evictable (Safari/ITP
~7 days, storage pressure), so treat it as best-effort. Keep the
`www.highline-freestyle.com` origin serving the new app through a grace window
before any redirect — redirecting immediately strips users of the origin that
holds their data. Note the live CNAME is the **`www.`** host; make sure the new
app is reachable there (not only the apex) or the stored data is unreachable.
