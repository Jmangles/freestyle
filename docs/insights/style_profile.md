# Style Profile Insights

Insights about a user's personal trick style, derived from the positions associated with their landed tricks.
Uses `tricks.start_position_id` and `tricks.end_position_id` joined via the `positions` table.

---

## Position Tendencies

**Most common start positions**
- Across all landed tricks, which starting positions appear most?
- e.g. "70% of your tricks start from Stand, 20% from Exposure"
- Reveals the user's comfort zone and dominant style

**Most common end positions**
- Same analysis for end positions
- Frequent end positions that differ from start positions indicate transition preferences

**Favorite position transitions**
- Most common start → end pairs across landed tricks
- e.g. "Stand → Exposure" being dominant suggests the user leans toward a specific trick family

---

## Exploration Gaps

**Positions never started from**
- Positions in the `positions` table with zero landed tricks for this user
- List of positions: Stand, Exposure, Nevermind, Sofa, Shoulder, Korean, Dropknee, Back, Chest, Double Dropknee, Leash, Rocket, Yisus, Soup
- Suggests areas to explore for a more rounded skill set

**Positions never ended in**
- Same analysis for end positions
- Some end positions may be rare in the trick database overall — filter to only show positions that exist on >= N approved tricks

---

## Possible Extensions

**Style archetype**
- Once enough data exists, cluster users by position preferences into named archetypes
- e.g. "Ground worker" (lots of back/chest), "Air player" (lots of stand/exposure), "Transition specialist" (diverse pairs)

**Trick recommendations by style**
- Suggest unlocked tricks that match the user's dominant position profile
- Prioritizes tricks they're likely to enjoy based on demonstrated preference

---

## Implementation Notes

- Only include tricks where consistency >= 1 (Once) — don't factor in tricks they're only Attempting
- Some tricks have null `start_position_id` or `end_position_id` — skip those for position analysis
- Position data is already joined in the `Trick` model (`startPositionName`, `endPositionName`) so no extra query needed
- This can be computed entirely client-side from the already-fetched trick + user_trick data
