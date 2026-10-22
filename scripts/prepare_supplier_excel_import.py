"""Read the supplied multi-row supplier list without modifying the workbook."""
import hashlib
import json
import re
from pathlib import Path

import openpyxl

SOURCE = Path(r'C:\Users\user\Downloads\test data.xlsx')
OUT = Path(__file__).resolve().parents[1] / 'dist/supplier-import-2026-10-22'
OUT.mkdir(parents=True, exist_ok=True)
sheet = openpyxl.load_workbook(SOURCE, data_only=True)['BAWANG']
records = []
current = None

def clean(value):
    return str(value).strip() if value is not None else ''

for row in range(6, sheet.max_row + 1):
    cells = {col: clean(sheet[f'{col}{row}'].value) for col in 'CDEFGHIJ'}
    if cells['C'].isdigit():
        current = None
        if not cells['D']:
            continue  # Empty numbered template row, not a supplier.
        current = {'source_number': int(cells['C']), 'source_sheet': sheet.title,
                   'source_rows': [], 'name_parts': [], 'address_parts': [], 'pic_parts': [],
                   'phones': [], 'items': [], 'service_areas': [], 'notes_parts': [], 'contacts': []}
        records.append(current)
    if current is None or not any(cells[col] for col in 'DEFGHIJ'):
        continue
    current['source_rows'].append(row)
    for col, key in [('D', 'name_parts'), ('E', 'address_parts'), ('F', 'pic_parts'),
                     ('G', 'phones'), ('H', 'items'), ('I', 'service_areas'), ('J', 'notes_parts')]:
        value = cells[col]
        if not value:
            continue
        if col in 'DE' and (re.match(r'https?://|www\.', value, re.I) or '@' in value):
            key = 'contacts'
        if value.casefold() not in [x.casefold() for x in current[key]]:
            current[key].append(value)

result = []
for row in records:
    item = {
        'source_number': row['source_number'], 'source_sheet': row['source_sheet'], 'source_rows': row['source_rows'],
        'name': ' '.join(row['name_parts']), 'pic_name': ' / '.join(row['pic_parts']) or None,
        'phone_number': ' / '.join(row['phones']) or None, 'address': '\n'.join(row['address_parts']) or None,
        'items': row['items'], 'service_areas': row['service_areas'], 'contacts': row['contacts'],
        'notes': '\n'.join(row['notes_parts']) or None,
        'latitude': None, 'longitude': None, 'coordinate_status': 'not_verified',
    }
    item['plus_codes'] = re.findall(r'\b[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{2,3}\b', item['address'] or '', re.I)
    result.append(item)

summary = {
    'source_file': SOURCE.name, 'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'supplier_count': len(result), 'numbered_blank_rows_ignored': [175],
    'missing_pic': [r['source_number'] for r in result if not r['pic_name']],
    'missing_phone': [r['source_number'] for r in result if not r['phone_number']],
    'missing_items': [r['source_number'] for r in result if not r['items']],
    'missing_address': [r['source_number'] for r in result if not r['address']],
    'plus_code_suppliers': [r['source_number'] for r in result if r['plus_codes']],
    'explicit_latitude_longitude': 0,
    'duplicate_names': sorted({r['name'] for r in result if sum(x['name'].casefold() == r['name'].casefold() for x in result) > 1}),
    'import_status': 'prepared_only_not_uploaded',
}
assert [r['source_number'] for r in result] == list(range(1, 45))
for name, data in [('suppliers-source.json', result), ('source-validation.json', summary)]:
    (OUT / name).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(summary, ensure_ascii=False, indent=2))
