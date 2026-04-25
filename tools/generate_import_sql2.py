import csv
from datetime import datetime

INPUT_CSV = 'trick-list - trick_list.csv'
OUTPUT_SQL = 'supabase/import_tricks2.sql'

# Normalise position names to match the first import
POSITION_MAP = {
    'DOUBLE DROP KNEE': 'DOUBLE DROPKNEE',
    'INWARD DROP KNEE': 'INWARD DROPKNEE',
    'DROP KNEE':        'DROPKNEE',
}

def normalise_pos(p):
    p = p.strip().upper() if p else ''
    return POSITION_MAP.get(p, p)

def parse_submitted(s):
    s = s.strip() if s else ''
    if not s:
        return 'now()'
    try:
        dt = datetime.strptime(s, '%d %b %Y')
        return f"'{dt.strftime('%Y-%m-%d')}'"
    except ValueError:
        return 'now()'

def parse_performed(month, year):
    month = month.strip() if month else ''
    year  = year.strip()  if year  else ''
    if not year:
        return 'null'
    if not month:
        return f"'{year.zfill(4)}-01-01'"
    try:
        dt = datetime.strptime(f'01 {month} {year}', '%d %b %Y')
        return f"'{dt.strftime('%Y-%m-%d')}'"
    except ValueError:
        try:
            dt = datetime.strptime(f'01 {month} {year}', '%d %B %Y')
            return f"'{dt.strftime('%Y-%m-%d')}'"
        except ValueError:
            return f"'{year.zfill(4)}-01-01'"

def sql_str(s):
    s = s.strip() if s else ''
    if not s:
        return 'null'
    return "'" + s.replace("'", "''") + "'"

def parse_difficulty(s):
    s = s.strip() if s else ''
    if not s or s.upper() == 'TBD':
        return '-1'
    try:
        n = int(s)
        if n == -1 or 1 <= n <= 10:
            return str(n)
    except ValueError:
        pass
    return '-1'

rows = []
positions = set()

with open(INPUT_CSV, encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        tech  = row['Technical name'].strip()
        given = row['Name'].strip()
        diff  = row['Difficulty'].strip()
        start = normalise_pos(row['Start position'])
        end   = normalise_pos(row['End position'])

        if not tech and not given:
            continue
        if not diff:
            continue

        if not given:
            given = tech
            tech = ''

        if start:
            positions.add(start)
        if end:
            positions.add(end)

        rows.append({
            'given':     given,
            'tech':      tech,
            'diff':      diff,
            'submitted': parse_submitted(row.get('dateAdded', '')),
            'performed': parse_performed(row['monthEstablished'], row['yearEstablished']),
            'performer': row['Original performer'],
            'desc':      row['description'],
            'tips':      row['tips'],
            'video':     row['linkToVideo'],
            'start':     start,
            'end':       end,
        })

lines = []
lines.append('-- ==============================================')
lines.append('-- Freestyle Highline – trick-list import')
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
lines.append('  t.given_name, t.technical_name, t.difficulty_tier::smallint,')
lines.append('  t.date_submitted::timestamptz, t.date_performed::date,')
lines.append('  t.original_performer, t.description, t.tips, t.video_link,')
lines.append('  sp.id, ep.id,')
lines.append("  1")
lines.append('from (values')

for i, r in enumerate(rows):
    comma = ',' if i < len(rows) - 1 else ''
    given     = sql_str(r['given'])
    tech      = sql_str(r['tech'])
    diff      = parse_difficulty(r['diff'])
    submitted = r['submitted']
    performed = r['performed']
    performer = sql_str(r['performer'])
    desc      = sql_str(r['desc'])
    tips      = sql_str(r['tips'])
    video     = sql_str(r['video'])
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
