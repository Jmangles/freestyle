#!/usr/bin/env python3
# Builds the legacy(bastislack/highline-freestyle) -> new(this app) trick-id
# mapping by matching trick names, since the two catalogs share no id space.
#
# Legacy source is the DEPLOYED app: branch `main`, built to gh-pages and served
# at www.highline-freestyle.com. Its predefined tricks (ids 10000+) live in
# src/predefinedTricksCombos.js as a CSV embedded in a template literal, and
# user progress is stored in the Dexie `userTricks` table keyed by that same id.
#
# Usage:
#   python3 tools/build_legacy_trick_map.py <predefinedTricksCombos.js> <seed_tricks.sql> <out_dir>
#
# predefinedTricksCombos.js: from a checkout of bastislack/highline-freestyle@main
# seed_tricks.sql:           this repo's supabase/seed_tricks.sql (the new catalog)
# out_dir:                   where the three CSVs are written

import os, re, io, csv, sys, json, difflib

if len(sys.argv) != 4:
    sys.exit(__doc__)
LEGACY_JS, SEED, OUT = sys.argv[1], sys.argv[2], sys.argv[3]

def norm(s):
    if not s:
        return ""
    s = s.lower().replace('&', ' and ')
    s = re.sub(r'[^a-z0-9]+', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()

# Alias-equivalence keys collapse the systematic naming differences between the
# two catalogs (the new one appended " Flip" to almighties and expanded DDK etc.)
# so a mechanical match still fires without fuzzy guessing.
ABBR = [('ddk', 'double drop knee'), ('nh', 'no hook'), ('oh', 'one hand')]
def keys_for(*names):
    ks = set()
    for name in names:
        b = norm(name)
        if not b:
            continue
        ks.add(b)
        ks.add(b[:-5] if b.endswith(' flip') else b + ' flip')
        for a, full in ABBR:
            ks.add(re.sub(r'\b%s\b' % a, full, b))
            ks.add(re.sub(r'\b%s\b' % re.escape(full), a, b))
    return ks

legacy = []
js = open(LEGACY_JS, encoding='utf-8').read()
block = re.search(r'predefinedTricks\s*=\s*`(.*?)`', js, re.S).group(1)
for r in csv.DictReader(io.StringIO(block.strip())):
    lid = (r.get('id') or '').strip()
    legacy.append({'id': int(lid) if lid.isdigit() else lid,
                   'tech': (r.get('technicalName') or '').strip() or None,
                   'alias': (r.get('alias') or '').strip() or None,
                   'start': (r.get('startPos') or '').strip() or None,
                   'end': (r.get('endPos') or '').strip() or None,
                   'diff': (r.get('difficultyLevel') or '').strip() or None})

cols = ['id','given_name','technical_name','difficulty_tier','date_submitted','date_performed',
        'original_performer','prerequisite_trick_ids','base_trick_ids','description','tips',
        'video_link','video_start','video_end','start_position_id','end_position_id','status','flags']

def split_sql_values(s):
    out, buf, i, depth, inq = [], [], 0, 0, False
    while i < len(s):
        c = s[i]
        if inq:
            if c == "'":
                if s[i+1:i+2] == "'":
                    buf.append("'"); i += 2; continue
                inq = False
            buf.append(c); i += 1; continue
        if c == "'":
            inq = True; buf.append(c); i += 1; continue
        if c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
        elif c == ',' and depth == 0:
            out.append(''.join(buf).strip()); buf = []; i += 1; continue
        buf.append(c); i += 1
    if buf:
        out.append(''.join(buf).strip())
    return out

def unq(v):
    v = v.strip()
    if v == 'null':
        return None
    if v.startswith("'") and v.endswith("'"):
        return v[1:-1].replace("''", "'")
    return v

newtricks = []
seed = open(SEED, encoding='utf-8').read()
for m in re.finditer(r'insert into tricks \([^)]*\) overriding system value values \((.*?)\);\n', seed, re.S):
    vals = split_sql_values(m.group(1))
    if len(vals) == len(cols):
        newtricks.append({c: unq(v) for c, v in zip(cols, vals)})

new_by_key = {}
for r in newtricks:
    r['_keys'] = keys_for(r.get('given_name'), r.get('technical_name'))
    for k in r['_keys']:
        new_by_key.setdefault(k, []).append(r)

new_norm = [(norm(r.get(f)), r) for r in newtricks for f in ('given_name','technical_name') if norm(r.get(f))]

def resolve(L, rows):
    lnames = {norm(L['tech']), norm(L['alias'])} - {''}
    def score(r):
        return len(({norm(r.get('given_name')), norm(r.get('technical_name'))} - {''}) & lnames)
    ranked = sorted(rows, key=score, reverse=True)
    if len(ranked) == 1:
        return ranked[0]
    return ranked[0] if score(ranked[0]) > score(ranked[1]) else None

# A discriminating token appearing on only one side (rotation, side, position,
# roll/flip direction) means the two names are almost certainly different tricks.
DISCRIMINATING = {'bs','fs','180','270','360','450','540','630','720','space','double','triple',
                  'nh','oh','back','front','reverse','sofa','crook','sit','belly','chest','korean',
                  'rocket','ddk','shoulder','fake','barrel','half','backroll','frontroll','backflip',
                  'frontflip','backbounce','frontbounce','hammockroll','hammock'}
FILLER = {'to','from','the','a','of','roll','flip','spin'}
def recommend(L, r):
    a = set(norm(L['tech'] or L['alias']).split())
    b = set(norm(r['technical_name'] or r['given_name']).split())
    return 'reject' if ((a ^ b) - FILLER) & DISCRIMINATING else 'suggest'

mapped, review, none = [], [], []
for L in legacy:
    lkeys = keys_for(L['tech'], L['alias'])
    base_keys = {norm(L['tech']), norm(L['alias'])} - {''}
    rows, seen = [], set()
    for k in lkeys:
        for r in new_by_key.get(k, []):
            if id(r) not in seen:
                seen.add(id(r)); rows.append(r)
    if rows:
        r = rows[0] if len(rows) == 1 else resolve(L, rows)
        if r is None:
            review.append((L, rows[0], 1.0)); continue
        r_base = {norm(r.get('given_name')), norm(r.get('technical_name'))} - {''}
        mapped.append((L, r, 'exact' if (base_keys & r_base) else 'rule')); continue
    best = None
    for (n, r) in new_norm:
        for lk in base_keys:
            s = difflib.SequenceMatcher(None, lk, n).ratio()
            if best is None or s > best[0]:
                best = (s, r)
    if best and best[0] >= 0.80:
        review.append((L, best[1], best[0]))
    else:
        none.append((L, best[1] if best else None, best[0] if best else 0))

# Human decisions on the review/no-equivalent tricks, kept in overrides.csv so
# they survive regeneration. A row with new_id set forces a confident match; a
# blank new_id forces "no equivalent". Overrides win over the automatic tiers.
legacy_by_id = {L['id']: L for L in legacy}
new_by_id = {int(r['id']): r for r in newtricks}
ov_path = os.path.join(OUT, 'overrides.csv')
overrides = {}
if os.path.exists(ov_path):
    for row in csv.DictReader(open(ov_path, encoding='utf-8')):
        lid = (row.get('legacy_id') or '').strip()
        nid = (row.get('new_id') or '').strip()
        if lid.isdigit():
            overrides[int(lid)] = int(nid) if nid.isdigit() else None

if overrides:
    ov_ids = set(overrides)
    mapped = [m for m in mapped if m[0]['id'] not in ov_ids]
    review = [m for m in review if m[0]['id'] not in ov_ids]
    none   = [m for m in none   if m[0]['id'] not in ov_ids]
    for lid, nid in overrides.items():
        L = legacy_by_id.get(lid)
        if L is None:
            continue
        if nid is not None and nid in new_by_id:
            mapped.append((L, new_by_id[nid], 'confirmed'))
        else:
            none.append((L, None, 0))

def write_csv(name, header, rows):
    with open(os.path.join(OUT, name), 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f); w.writerow(header); w.writerows(rows)

write_csv('trick_id_map.csv',
    ['legacy_id','new_id','tier','legacy_name','new_name'],
    [[L['id'], int(r['id']), t, L['tech'] or L['alias'] or '', r['technical_name'] or r['given_name'] or '']
     for L,r,t in sorted(mapped, key=lambda x:x[0]['id'])])

rec = [(L,r,s,recommend(L,r)) for (L,r,s) in sorted(review, key=lambda x:-x[2])]
write_csv('trick_id_map_review.csv',
    ['recommendation','score','legacy_id','legacy_name','suggested_new_id','suggested_new_name','confirmed_new_id'],
    [[rc, round(s,3), L['id'], L['tech'] or L['alias'] or '', int(r['id']), r['technical_name'] or r['given_name'] or '', '']
     for L,r,s,rc in rec])

write_csv('trick_id_map_none.csv',
    ['legacy_id','legacy_name','start','end','difficulty','closest_new_name'],
    [[L['id'], L['tech'] or L['alias'] or '', L['start'] or '', L['end'] or '', L['diff'] or '',
      (r['technical_name'] or r['given_name']) if r else '']
     for L,r,s in sorted(none, key=lambda x:x[0]['id'])])

# The app ships the same mapping as a bundled asset, so the importer never has
# to parse CSV at runtime.
asset = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                     'assets', 'legacy', 'trick_id_map.json')
if os.path.isdir(os.path.dirname(asset)):
    with open(asset, 'w', encoding='utf-8') as f:
        json.dump({str(L['id']): int(r['id']) for L, r, _ in sorted(mapped, key=lambda x: x[0]['id'])},
                  f, indent=0, sort_keys=True)
        f.write('\n')

exact_n = sum(1 for _,_,t in mapped if t == 'exact')
rule_n = sum(1 for _,_,t in mapped if t == 'rule')
conf_n = sum(1 for _,_,t in mapped if t == 'confirmed')
print("legacy %d  new %d" % (len(legacy), len(newtricks)))
print("confident %d (exact %d, rule %d, confirmed %d)  review %d  none %d" %
      (len(mapped), exact_n, rule_n, conf_n, len(rec), len(none)))
