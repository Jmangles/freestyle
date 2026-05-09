# Personal Progress Insights

Insights derived from the `user_tricks` table joined with `tricks` and `positions`.

---

## Progression Snapshot

**Tricks landed overview**
- Total tricks landed (consistency >= 1 / "Once") vs. total approved tricks in the database
- Displayed as a count and percentage — gives users a sense of where they stand in the full trick catalog

**Hardest trick landed**
- The trick with the highest `difficulty_tier` where the user has consistency >= 1
- Could show tier number + trick name as a headline stat

**Difficulty tier breakdown**
- Bar or segmented chart: how many tricks landed per difficulty band (e.g. Tier 1-5, 6-10, 11-15, etc.)
- Reveals whether a user is broad (many easy tricks) or narrow (few hard tricks)

**Consistency distribution**
- Pie or bar chart showing how many tricks sit at each consistency level:
  - Attempting / Once / Sometimes / Often / Generally / Always
- Helps users see if they have a lot of "Attempting" tricks they've stalled on

---

## What's Next

**Unlocked tricks not yet attempted**
- Tricks where all `prerequisite_trick_ids` are in the user's landed set, but no `user_tricks` row exists for that trick yet
- Actionable list — these are ready to start working on immediately

**Tricks you have at least one prerequisite for**
- Tricks where the user has at least one of the prerequisites landed
- Shows users what to focus on to unlock the most new content

**High-value prerequisite targets**
- Tricks that, once landed, unlock the greatest number of immediate next tricks (graph traversal on `prerequisite_trick_ids`)
- Encourages strategic progression rather than random exploration

---

## Implementation Notes

- "Landed" threshold for prerequisite logic should be consistency >= 1 (Once), not just Attempting
- Difficulty tier -1 (TBD) tricks should be grouped separately, not mixed into tier bands
- Prerequisite graph can be computed client-side from the full tricks list since the array is already fetched
