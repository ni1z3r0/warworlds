"""Check that every Wells quote in the game is word-for-word in the novel.

  python3 tools/check_quotes.py

Checks text inside \"...\" in scripts/story.gd and scripts/house/house_mode.gd,
the "desc"/"line" fields in scripts/cast.gd, and the Curate's MUTTER/SHOUTS lines against the-war-of-the-worlds.txt (Project Gutenberg).
Apostrophes, dashes and whitespace are normalised before comparing.
"""
import re, sys, pathlib

root = pathlib.Path(__file__).resolve().parent.parent

def norm(s):
    s = s.replace('_', '').replace('’', "'").replace('‘', "'")
    s = s.replace('“', '"').replace('”', '"').replace('—', '-')
    return re.sub(r'\s+', ' ', s).strip()

novel = norm((root / 'the-war-of-the-worlds.txt').read_text(encoding='utf-8'))
quotes = []
story = (root / 'scripts/story.gd').read_text(encoding='utf-8')
quotes += [('story.gd', q) for q in re.findall(r'\\"(.+?)\\"', story)]
cast = (root / 'scripts/cast.gd').read_text(encoding='utf-8')
quotes += [('cast.gd', q) for q in re.findall(r'"(?:desc|line)": "(.*?)",\n', cast) if q]

house = (root / 'scripts/house/house_mode.gd').read_text(encoding='utf-8')
for name in ('MUTTER', 'SHOUTS'):
    block = re.search(name + r' := \[(.*?)\]', house, re.S).group(1)
    quotes += [('house_mode.gd', q) for q in re.findall(r'"(.*?)"', block)]
quotes += [('house_mode.gd', q) for q in re.findall(r'\\"(.+?)\\"', house)]

bad = 0
for src, q in quotes:
    qn = norm(q).rstrip('.,!?')
    if qn not in novel:
        bad += 1
        print(f'MISSING ({src}): {q}')
print(f'{len(quotes)} quotes checked, {bad} not found in the novel.')
sys.exit(1 if bad else 0)
