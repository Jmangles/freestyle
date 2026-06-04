# Database Schema

Current Supabase (PostgreSQL) schema. All tables are in the `public` schema.

---

## `positions`

Lookup table for trick start/end positions (e.g. "Chest", "Back").

```sql
CREATE TABLE public.positions (
  id   SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL UNIQUE
);
```

---

## `profiles`

One row per authenticated user. `id` links to Supabase Auth; `int_id` is used as the FK throughout the app because integer joins are faster and friendlier than UUIDs.

```sql
CREATE TABLE public.profiles (
  id     UUID    NOT NULL UNIQUE,
  int_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  username TEXT UNIQUE,
  flags  SMALLINT NOT NULL DEFAULT 0,

  CONSTRAINT profiles_id_fkey FOREIGN KEY (id)
    REFERENCES auth.users (id) ON DELETE CASCADE
);
```

`flags` is a bitmask (reserved for future role/permission bits).

---

## `tricks`

Core trick database. `status` mirrors the `ApprovalStatus` enum (0 = pending, 1 = approved, 2 = rejected). `difficulty_tier` is 1–30 or -1 (unrated). `flags` is a bitmask: bit 0 = is_core, bit 1 = has_training_video.

```sql
CREATE TABLE public.tricks (
  id                    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  given_name            TEXT     NOT NULL,
  technical_name        TEXT,
  difficulty_tier       SMALLINT NOT NULL,
  date_submitted        TIMESTAMPTZ NOT NULL DEFAULT now(),
  date_performed        DATE,
  original_performer    TEXT,
  prerequisite_trick_ids INTEGER[] NOT NULL DEFAULT '{}',
  description           TEXT,
  tips                  TEXT,
  video_link            TEXT,
  video_start           SMALLINT,
  video_end             SMALLINT,
  start_position_id     SMALLINT REFERENCES positions (id),
  end_position_id       SMALLINT REFERENCES positions (id),
  status                SMALLINT NOT NULL DEFAULT 0,
  submitted_by          INTEGER  REFERENCES profiles (int_id) ON DELETE SET NULL,
  flags                 SMALLINT NOT NULL DEFAULT 0,

  CONSTRAINT tricks_difficulty_tier_check CHECK (
    difficulty_tier = -1 OR (difficulty_tier >= 1 AND difficulty_tier <= 30)
  ),
  CONSTRAINT tricks_status_check CHECK (status >= 0 AND status <= 2)
);
```

---

## `user_tricks`

Tracks each user's progress on a trick. One row per (user, trick) pair. `consistency` mirrors the `Consistency` enum (0 = Attempting … 5 = Always). `leash_position` mirrors `LeashPosition` (0 = Frontside, 1 = Backside, 2 = Center).

```sql
CREATE TABLE public.user_tricks (
  id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id         INTEGER  NOT NULL REFERENCES profiles (int_id) ON DELETE CASCADE,
  trick_id        INTEGER  NOT NULL REFERENCES tricks (id)       ON DELETE CASCADE,
  consistency     SMALLINT NOT NULL DEFAULT 0,
  difficulty_vote SMALLINT,
  leash_position  SMALLINT,
  video_link      TEXT,
  video_start     SMALLINT,
  video_end       SMALLINT,

  CONSTRAINT user_tricks_user_id_trick_id_key UNIQUE (user_id, trick_id),
  CONSTRAINT user_tricks_consistency_check    CHECK (consistency     >= 0 AND consistency     <= 5),
  CONSTRAINT user_tricks_difficulty_vote_check CHECK (difficulty_vote >= 1 AND difficulty_vote <= 30),
  CONSTRAINT user_tricks_leash_position_check CHECK (leash_position  >= 0 AND leash_position  <= 2)
);
```

---

## `trick_annotations`

Time-stamped video annotations for the Training Studio. Editors add these to highlight cues at specific moments in the training video. `language` is an ISO 639-1 code.

```sql
CREATE TABLE public.trick_annotations (
  id         SERIAL      PRIMARY KEY,
  trick_id   INTEGER     NOT NULL REFERENCES tricks (id) ON DELETE CASCADE,
  created_by INTEGER     NOT NULL REFERENCES profiles (int_id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  start_ms   INTEGER     NOT NULL,
  end_ms     INTEGER     NOT NULL,
  text       TEXT        NOT NULL,
  language   TEXT        NOT NULL DEFAULT 'en'
);
```

---

## `tips`

General highlining tips (not trick-specific). `status` is a boolean (false = pending, true = approved). `type` mirrors the `TipType` enum (0–2).

```sql
CREATE TABLE public.tips (
  id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title           TEXT     NOT NULL,
  header          TEXT,
  body            TEXT     NOT NULL,
  type            SMALLINT NOT NULL DEFAULT 0,
  status          BOOLEAN  NOT NULL DEFAULT false,
  submitted_on    DATE     NOT NULL DEFAULT CURRENT_DATE,
  submitted_by    INTEGER  REFERENCES profiles (int_id) ON DELETE SET NULL,
  approved_on     DATE,
  approved_by     INTEGER  REFERENCES profiles (int_id) ON DELETE SET NULL,
  last_updated    DATE,
  last_updated_by INTEGER  REFERENCES profiles (int_id) ON DELETE SET NULL,

  CONSTRAINT tips_type_check CHECK (type >= 0 AND type <= 2)
);
```

---

## `trick_suggestions`

User-submitted edits to an existing trick, held for admin review. Fields are nullable because a suggestion only needs to include the fields the user wants to change. Approved suggestions are merged into `tricks` and then deleted.

```sql
CREATE TABLE public.trick_suggestions (
  id                    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  trick_id              INTEGER     NOT NULL REFERENCES tricks (id) ON DELETE CASCADE,
  submitted_by          INTEGER     REFERENCES profiles (int_id) ON DELETE SET NULL,
  date_submitted        TIMESTAMPTZ NOT NULL DEFAULT now(),
  given_name            TEXT,
  technical_name        TEXT,
  difficulty_tier       SMALLINT,
  date_performed        DATE,
  original_performer    TEXT,
  prerequisite_trick_ids INTEGER[],
  description           TEXT,
  tips                  TEXT,
  video_link            TEXT,
  video_start           INTEGER,
  video_end             INTEGER,
  start_position_id     SMALLINT REFERENCES positions (id),
  end_position_id       SMALLINT REFERENCES positions (id),

  CONSTRAINT trick_suggestions_difficulty_tier_check CHECK (
    difficulty_tier = -1 OR (difficulty_tier >= 1 AND difficulty_tier <= 30)
  )
);
```
