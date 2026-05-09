# Community Intelligence Insights

Insights aggregated across all users, surfacing patterns that no individual's data could reveal alone.
Primarily derived from `user_tricks.difficulty_vote`, `user_tricks.leash_position`, and row counts.

---

## Crowd-Sourced Difficulty

**Community rating vs. official tier**
- For each trick, compare the average `difficulty_vote` across all users against `tricks.difficulty_tier`
- Surface tricks with the largest divergence — e.g. "Community rates this a 12, official tier is 7"
- Useful for calibrating the difficulty scale and flagging tricks that need re-review

**Most controversial tricks**
- Tricks with the highest variance / standard deviation in `difficulty_vote`
- Indicates tricks where difficulty is highly skill-path-dependent (some routes make it easier)
- Could display as a "This trick is debated" badge

**User's personal calibration**
- Show how a user's own votes compare to the community average across all their voted tricks
- "You tend to rate tricks 2 points harder than the community" — reveals personal bias or style mismatch

---

## Leash Position Consensus

**Community split per trick**
- Pie or segmented bar showing frontside / backside / center breakdown from `user_tricks.leash_position`
- Shown on each trick's detail page — helps beginners pick an approach
- Only meaningful once there are enough votes (show a minimum threshold, e.g. 5 responses)

**User's leash preference vs. community**
- Does the user consistently pick the minority leash position? Flag it — they might be making things harder

---

## Popularity & Rarity

**Most attempted tricks**
- Tricks with the most `user_tricks` rows regardless of consistency — shows popular learning targets
- Good for surfacing "starter tricks" for new users

**Most landed tricks**
- Tricks with the most rows where consistency >= 1 — the community's commonly-completed tricks

**Rarest landed tricks**
- Tricks landed by the fewest users (absolute count or percentage of total users)
- Bragging rights — highlight when a user lands one of these

---

## Implementation Notes

- All aggregations need to exclude `consistency = 0` (Attempting) rows when counting "landed"
- Vote stats RPC (`add_vote_stats_function.sql`) already exists — extend it or add a new function for difficulty variance
- Minimum vote thresholds prevent misleading stats on tricks with 1-2 votes — configure per-metric
- Consider caching aggregated stats (e.g. via a materialized view or edge function) rather than computing on every load
