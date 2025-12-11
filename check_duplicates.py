import json
from collections import defaultdict

with open('schools.json', 'r', encoding='utf-8') as f:
    schools = json.load(f)

school_names = [s['school_name'] for s in schools]
prefixed_schools = defaultdict(list)

for name in school_names:
    if name.startswith('서울'):
        prefixed_schools['서울'].append(name)
    elif name.startswith('부산'):
        prefixed_schools['부산'].append(name)
    elif name.startswith('대구'):
        prefixed_schools['대구'].append(name)
    elif name.startswith('인천'):
        prefixed_schools['인천'].append(name)
    elif name.startswith('광주'):
        prefixed_schools['광주'].append(name)
    elif name.startswith('대전'):
        prefixed_schools['대전'].append(name)
    elif name.startswith('울산'):
        prefixed_schools['울산'].append(name)
    elif name.startswith('세종'):
        prefixed_schools['세종'].append(name)
    elif name.startswith('경기'):
        prefixed_schools['경기'].append(name)
    elif name.startswith('강원'):
        prefixed_schools['강원'].append(name)
    elif name.startswith('충북'):
        prefixed_schools['충북'].append(name)
    elif name.startswith('충남'):
        prefixed_schools['충남'].append(name)
    elif name.startswith('전북'):
        prefixed_schools['전북'].append(name)
    elif name.startswith('전남'):
        prefixed_schools['전남'].append(name)
    elif name.startswith('경북'):
        prefixed_schools['경북'].append(name)
    elif name.startswith('경남'):
        prefixed_schools['경남'].append(name)
    elif name.startswith('제주'):
        prefixed_schools['제주'].append(name)

# Find duplicates if prefix is removed
duplicates = defaultdict(list)
all_unprefixed_names = set()

for prefix, names in prefixed_schools.items():
    for name in names:
        unprefixed_name = name[len(prefix):]
        if unprefixed_name in all_unprefixed_names:
            duplicates[unprefixed_name].append(name)
        else:
            all_unprefixed_names.add(unprefixed_name)

# also add the ones that were already in the list
for unprefixed_name in duplicates:
    for prefix, names in prefixed_schools.items():
        for name in names:
            if name[len(prefix):] == unprefixed_name:
                if name not in duplicates[unprefixed_name]:
                    duplicates[unprefixed_name].append(name)


print(f"Found {len(duplicates)} duplicate school names if prefix is removed.")
for unprefixed_name, original_names in duplicates.items():
    print(f"- {unprefixed_name}: {original_names}")

