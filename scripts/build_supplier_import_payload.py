import csv
import json
from collections import Counter
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'dist/supplier-import-2026-10-22'
rows = json.loads((OUT / 'suppliers-geocoded.json').read_text(encoding='utf-8'))
summary = json.loads((OUT / 'source-validation.json').read_text(encoding='utf-8'))
source_hash = summary['source_sha256']
assert len(rows) == 44 and all(r['latitude'] is not None and r['longitude'] is not None for r in rows)
# Use districts explicitly named in the workbook rather than the approximate point's neighbouring district.
source_districts = {1:'Jatinegara', 10:'Junrejo', 13:'Tegalsari', 16:'Alalak', 17:'Landasan Ulin',
    18:'Banjarmasin Selatan', 20:'Banjarmasin Tengah', 21:'Harjamukti', 22:'Waled', 23:'Kadipaten',
    24:'Kersana', 25:'Pabedilan', 26:'Gunungjati', 27:'Medan Tuntungan', 28:'Medan Tuntungan',
    33:'Kota Gajah', 34:'Metro Timur', 35:'Rajabasa', 36:'Jati Agung', 37:'Tanjung Karang Pusat',
    39:'Seberang Ulu I', 41:'Alang-Alang Lebar', 42:'Sukarami', 43:'Ilir Timur II', 44:'Seberang Ulu I'}
payload = {'source_sha256': source_hash, 'records': []}
audit = []
for r in rows:
    no = r['source_number']
    if r['coordinate_status'] == 'plus_code':
        location_note = f"Lokasi dari Plus Code pada Excel: {r['plus_codes'][0]} ({r['full_plus_code']}). Belum diverifikasi melalui kunjungan GPS."
    elif no == 19:
        location_note = 'PERKIRAAN SANGAT KASAR: alamat hanya Kalimantan. Titik acuan regional memakai pusat Kalimantan Tengah di bagian Indonesia, BUKAN lokasi pasti supplier. Provinsi/kota supplier belum diketahui.'
    else:
        location_note = f"TITIK PERKIRAAN berdasarkan alamat/wilayah, bukan lokasi GPS pasti supplier. Acuan peta: {r['geocode_match']}."
    extra = []
    if no == 8:
        extra.append('Excel mencantumkan 3 alamat. Titik utama memakai alamat pertama di Surabaya. Alamat Semarang dan Jakarta tetap dipertahankan di kolom Alamat.')
    if no == 31:
        extra.append('Perlu verifikasi: nama menyebut Pekanbaru tetapi alamat dan wilayah pada Excel menyebut Medan. Titik sementara mengikuti alamat Medan.')
    if no == 40:
        extra.append('Alamat kosong pada Excel; titik sementara menggunakan wilayah Palembang yang tercantum pada Excel.')
    missing = [label for field,label in [('pic_name','PIC'),('phone_number','telepon'),('items','jenis kebutuhan'),('address','alamat')] if not r[field]]
    if missing:
        extra.append('Belum tercantum pada Excel: '+', '.join(missing)+'.')
    notes = [location_note]
    if r['notes']: notes.append(r['notes'])
    if r['service_areas']: notes.append('Wilayah pada Excel: '+', '.join(r['service_areas']))
    if r['contacts']: notes.append('Kontak/link tambahan: '+'; '.join(r['contacts']))
    notes += extra
    notes.append('Sumber koordinat: OpenStreetMap contributors / Nominatim (ODbL), https://www.openstreetmap.org/copyright')
    notes.append(f"Sumber data: test data.xlsx, BAWANG, No. {no}, baris {min(r['source_rows'])}-{max(r['source_rows'])}.")
    notes.append(f'[Impor HSF {no} / {source_hash[:12]}]')
    supplier = {k:r.get(k) for k in ['name','pic_name','phone_number','address','territory_province','territory_city','territory_district','items','latitude','longitude']}
    supplier['phone_number'] = supplier['phone_number'] or ''
    if no in source_districts: supplier['territory_district'] = source_districts[no]
    supplier['location_source'] = 'map'
    supplier['notes'] = '\n\n'.join(notes)
    assert len(supplier['notes']) <= 3000, no
    assert len(supplier['phone_number']) <= 32, no
    payload['records'].append({'source_number': no, 'supplier': supplier})
    audit.append({'no_excel':no,'nama_supplier':r['name'],'alamat_excel':r['address'] or '',
        'latitude':r['latitude'],'longitude':r['longitude'],'jenis_titik':r['coordinate_status'],
        'acuan_peta':r['geocode_match'],'catatan_verifikasi':' '.join(extra),
        'link_peta':f"https://www.openstreetmap.org/?mlat={r['latitude']}&mlon={r['longitude']}#map=16/{r['latitude']}/{r['longitude']}"})
(OUT / 'supplier-import-payload.json').write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')
with (OUT / 'pemeriksaan-titik-supplier.csv').open('w', encoding='utf-8-sig', newline='') as file:
    writer = csv.DictWriter(file, fieldnames=audit[0].keys())
    writer.writeheader(); writer.writerows(audit)
print(json.dumps({'records':len(rows), 'coordinate_status':dict(Counter(r['coordinate_status'] for r in rows)),
    'max_note_length':max(len(r['supplier']['notes']) for r in payload['records']),
    'all_have_coordinates':True}, indent=2))
