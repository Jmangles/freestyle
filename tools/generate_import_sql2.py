import csv
from datetime import datetime

INPUT_CSV = 'trick-list - trick_list.csv'
OUTPUT_SQL = 'supabase/import_tricks2.sql'

# Normalise position names to match what's already in the DB
POSITION_MAP = {
    'DOUBLE DROP KNEE': 'DOUBLE DROPKNEE',
    'INWARD DROP KNEE': 'INWARD DROPKNEE',
}

def normalise_pos(p):
    p = p.strip().upper()
    return POSITION_MAP.get(p, p)

def parse_date_added(s):
    s = s.strip()
    if not s:
        return 'now()'
    for fmt in ('%d %b %Y', '%b %d %Y', '%Y-%m-%d'):
        try:
            dt = datetime.strptime(s, fmt)
            return f"'{dt.strftime('%Y-%m-%d')}'"
        except ValueError:
            pass
    return 'now()'

def parse_performed(month, year):
    month = month.strip()
    year = year.strip()
    if year and month:
        try:
            dt = datetime.strptime(f'01 {month} {year}', '%d %m %Y')
            return f"'{dt.strftime('%Y-%m-%d')}'"
        except ValueError:
            pass
        try:
            dt = datetime.strptime(f'01 {month} {year}', '%d %B %Y')
            return f"'{dt.strftime('%Y-%m-%d')}'"
        except ValueError:
            pass
    if year:
        return f"'{year.zfill(4)}-01-01'"
    return 'null'

def sql_str(s):
    s = s.strip() if s else ''
    if not s:
        return 'null'
    return "'" + s.replace("'", "''") + "'"

def build_video(url, start_time):
    url = url.strip()
    if not url:
        return 'null'
    start_time = start_time.strip()
    if start_time and '?t=' not in url and '&t=' not in url:
        sep = '&' if '?' in url else '?'
        url = f'{url}{sep}t={start_time}'
    return sql_str(url)

rows = []
positions = set()

with open(INPUT_CSV, encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        tech  = row['Technical name'].strip()
        given = row['Name'].strip()
        diff  = row['difficultyLevel'].strip()
        start = normalise_pos(row['startPos'])
        end   = normalise_pos(row['endPos'])

        if not tech and not given:
            continue

        # Promote technical name to given name if no given name
        if not given:
            given = tech
            tech = ''

        # Normalise difficulty: blank or '?' → 'TBD'
        if not diff or diff == '?':
            diff = 'TBD'

        if start:
            positions.add(start)
        if end:
            positions.add(end)

        rows.append({
            'given':      given,
            'tech':       tech,
            'diff':       diff,
            'submitted':  parse_date_added(row['dateAdded']),
            'performed':  parse_performed(row['monthEstablished'], row['yearEstablished']),
            'performer':  row['performed b'].strip(),
            'desc':       row['description'].strip(),
            'tips':       row['tips'].strip(),
            'video':      build_video(row['linkToVideo'], row['videoStartTime']),
            'start':      start,
            'end':        end,
        })

# Only insert positions not already present (ON CONFLICT DO NOTHING handles dupes)
lines = []
lines.append('-- ==============================================')
lines.append('-- Trick-list CSV import (second batch)')
lines.append('-- ==============================================\n')

lines.append('insert into positions (name) values')
sorted_pos = sorted(positions)
for i, p in enumerate(sorted_pos):
    comma = ',' if i < len(sorted_pos) - 1 else ''
    lines.append(f"  ('{p}'){comma}")
lines.append('on conflict (name) do nothing;\n')

lines.append('with pos as (select id, name from positions)')
lines.append('insert into tricks (')
lines.append('  given_name, technical_name, difficulty_tier,')
lines.append('  date_submitted, date_performed, original_performer,')
lines.append('  description, tips, video_link,')
lines.append('  start_position_id, end_position_id, status')
lines.append(')')
lines.append('select')
lines.append('  t.given_name, t.technical_name, t.difficulty_tier,')
lines.append('  t.date_submitted::timestamptz, t.date_performed::date,')
lines.append('  t.original_performer, t.description, t.tips, t.video_link,')
lines.append('  sp.id, ep.id,')
lines.append("  'approved'")
lines.append('from (values')

for i, r in enumerate(rows):
    comma = ',' if i < len(rows) - 1 else ''
    given     = sql_str(r['given'])
    tech      = sql_str(r['tech'])
    diff      = sql_str(r['diff'])
    submitted = r['submitted']
    performed = r['performed']
    performer = sql_str(r['performer'])
    desc      = sql_str(r['desc'])
    tips      = sql_str(r['tips'])
    video     = r['video']
    start     = sql_str(r['start']) if r['start'] else 'null'
    end       = sql_str(r['end'])   if r['end']   else 'null'
    lines.append(
        f'  ({given},{tech},{diff},{submitted},{performed},'
        f'{performer},{desc},{tips},{video},{start},{end}){comma}'
    )

lines.append(') as t(given_name,technical_name,difficulty_tier,date_submitted,date_performed,')
lines.append('       original_performer,description,tips,video_link,start_pos,end_pos)')
lines.append('left join pos sp on sp.name = t.start_pos')
lines.append('left join pos ep on ep.name = t.end_pos;')

sql = '\n'.join(lines)
with open(OUTPUT_SQL, 'w', encoding='utf-8') as out:
    out.write(sql)

print(f"Done – wrote {OUTPUT_SQL} ({len(rows)} tricks, {len(positions)} positions)")
