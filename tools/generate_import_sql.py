import csv
from datetime import datetime


def parse_submitted(date_str):
    date_str = date_str.strip()
    if not date_str or date_str == '-':
        return 'now()'
    try:
        dt = datetime.strptime(date_str, '%d/%m/%Y %H:%M:%S')
        return f"'{dt.strftime('%Y-%m-%d %H:%M:%S')}'"
    except Exception:
        return 'now()'


def parse_performed(date_str):
    date_str = date_str.strip()
    if not date_str or date_str == '-':
        return 'null'
    try:
        dt = datetime.strptime(date_str, '%d/%m/%Y')
        return f"'{dt.strftime('%Y-%m-%d')}'"
    except Exception:
        return 'null'


def sql_str(s):
    s = s.strip() if s else ''
    if not s:
        return 'null'
    return "'" + s.replace("'", "''") + "'"


rows = []
positions = set()

with open('tricks.csv', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        given  = row['Name'].strip()
        tech   = row['Technical Name'].strip()
        diff   = row['Difficulty'].strip()
        start  = row['Start position'].strip().upper()
        end    = row['End position'].strip().upper()

        # Skip rows with no meaningful name or missing required fields
        if not given and not tech:
            continue
        if not diff:
            continue
        # If no given name, promote technical name
        if not given:
            given = tech
            tech = ''

        if start:
            positions.add(start)
        if end:
            positions.add(end)

        rows.append({
            'given':      given,
            'tech':       tech,
            'diff':       diff,
            'submitted':  row['Submitted on'],
            'performed':  row['Original date performed'],
            'performer':  row['Original performer'],
            'desc':       row['Description'],
            'tips':       row['Do you have any tips?'],
            'video':      row['Video link'],
            'start':      start,
            'end':        end,
        })

lines = []
lines.append('-- ==============================================')
lines.append('-- Freestyle Highline – trick data import')
lines.append('-- ==============================================\n')

# Positions
lines.append('insert into positions (name) values')
sorted_pos = sorted(positions)
for i, p in enumerate(sorted_pos):
    comma = ',' if i < len(sorted_pos) - 1 else ''
    lines.append(f"  ('{p}'){comma}")
lines.append('on conflict (name) do nothing;\n')

# Tricks via CTE so we can resolve position IDs inline
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
    submitted = parse_submitted(r['submitted'])
    performed = parse_performed(r['performed'])
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
with open('supabase/import_tricks.sql', 'w', encoding='utf-8') as out:
    out.write(sql)

print(f"Done – wrote supabase/import_tricks.sql ({len(rows)} tricks, {len(positions)} positions)")
