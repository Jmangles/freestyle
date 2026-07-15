# Converts PostgREST JSON (positions + tricks) into plain-SQL INSERT statements.
# Used by scripts/refresh-seed.sh. Expects {positions: [...], tricks: [...]}.
# submitted_by is intentionally dropped so the seed carries no user reference.

def lit: if . == null then "null" else "'" + (tostring | gsub("'"; "''")) + "'" end;
def num: if . == null then "null" else tostring end;
def arr: if . == null then "'{}'" else "'{" + (map(tostring) | join(",")) + "}'" end;

( .positions[]
  | "insert into positions (id, name) overriding system value values "
    + "(" + (.id|num) + ", " + (.name|lit) + ");"
),
( .tricks[]
  | "insert into tricks (id, given_name, technical_name, difficulty_tier, date_submitted, date_performed, original_performer, prerequisite_trick_ids, base_trick_ids, description, tips, video_link, video_start, video_end, start_position_id, end_position_id, status, flags) overriding system value values ("
    + (.id|num) + ", "
    + (.given_name|lit) + ", "
    + (.technical_name|lit) + ", "
    + (.difficulty_tier|num) + ", "
    + (.date_submitted|lit) + ", "
    + (.date_performed|lit) + ", "
    + (.original_performer|lit) + ", "
    + (.prerequisite_trick_ids|arr) + ", "
    + (.base_trick_ids|arr) + ", "
    + (.description|lit) + ", "
    + (.tips|lit) + ", "
    + (.video_link|lit) + ", "
    + (.video_start|num) + ", "
    + (.video_end|num) + ", "
    + (.start_position_id|num) + ", "
    + (.end_position_id|num) + ", "
    + (.status|num) + ", "
    + (.flags|num) + ");"
)
