# Admin & Platform Health Insights

Insights for admins to monitor content quality, moderation queue, and user engagement.
Relevant to `admin_screen.dart` and the approval/suggestion workflows.

---

## Moderation Queue Health

**Pending trick submissions**
- Count of tricks with `status = 0` (pending)
- Age of oldest pending submission (`date_submitted`) — flags backlog buildup
- Could show a warning if any submission is older than X days

**Pending trick suggestions**
- Count of rows in `trick_suggestions` table
- Grouped by trick — if one trick has many suggestions, it may need a larger overhaul
- Age of oldest suggestion (`date_submitted`)

---

## Content Quality

**Tricks missing key metadata**
- No `video_link` — community has no reference footage
- `difficulty_tier = -1` (TBD) — not yet rated; how many tricks are unrated?
- No `description` — bare-bones entries
- No `original_performer` — provenance unknown
- No `start_position_id` or `end_position_id` — not fully categorized
- Surface as a list admins can work through to improve data quality

**Prerequisite orphans**
- Tricks that reference a `prerequisite_trick_id` pointing to a non-existent or rejected trick
- Would silently block users from seeing those tricks as unlocked

---

## User Engagement

**Active users**
- Users who have at least one `user_tricks` row — vs. total registered profiles
- Shows what % of sign-ups actually engage with progression tracking

**Trick coverage**
- Distribution of how many tricks each user has logged — identify power users vs. one-time visitors
- e.g. "40% of users have logged fewer than 5 tricks"

**Submission funnel**
- Total tricks submitted (all statuses) vs. approved vs. rejected
- Approval rate — if rejection rate is high, submission guidelines may need improvement

---

## Implementation Notes

- Most of these can be simple Supabase count queries with filters — no complex aggregation needed
- Consider a dedicated admin RPC or view to bundle multiple counts into one round-trip
- Some stats (like prerequisite orphans) are one-time audit queries, not realtime dashboards
- User engagement stats require careful RLS — ensure admin-only access to aggregate profile data
