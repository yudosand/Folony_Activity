"""One-off, cached, single-thread OSM lookup for the user-approved supplier import."""
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.tooling/supplier-geocode-deps'))
from openlocationcode import openlocationcode as olc

OUT = ROOT / 'dist/supplier-import-2026-10-22'
CACHE = OUT / 'geocode-cache.json'
cache = json.loads(CACHE.read_text(encoding='utf-8')) if CACHE.exists() else {}
records = json.loads((OUT / 'suppliers-source.json').read_text(encoding='utf-8'))
last_request = 0

# Start with the street/market named in the workbook, then use the nearest named area.
# No phone numbers, PICs, commercial terms or other private notes are sent.
queries = {
1: ['Jalan Bekasi Timur Raya, Jakarta Timur', 'Cipinang Besar Utara, Jakarta'],
2: ['Kalideres Permai, Jakarta Barat', 'Kalideres, Jakarta Barat'],
3: ['Jalan Peternakan II, Jakarta Barat', 'Cengkareng, Jakarta Barat'],
4: ['Karawaci, Tangerang'],
5: ['Jalan Peternakan II, Jakarta Barat', 'Cengkareng, Jakarta Barat'],
6: ['Tanggul Kali Angke, Wijaya Kusuma, Jakarta', 'Wijaya Kusuma, Jakarta Barat'],
7: ['Cilincing, Jakarta Utara'],
8: ['Jalan Tanjung Batu, Surabaya', 'Perak Barat, Surabaya'],
9: ['Jalan Peternakan, Cengkareng, Jakarta', 'Cengkareng, Jakarta Barat'],
10: ['Junrejo, Kota Batu'],
11: ['Pasar Caringin, Bandung', 'Babakan Ciparay, Bandung'],
12: ['Gunungpati, Semarang'],
13: ['Jalan Pandegiling, Keputran, Surabaya', 'Keputran, Surabaya'],
14: ['Brebes, Jawa Tengah'],
15: ['Sidoarjo, Jawa Timur'],
16: ['Jalan Trans Kalimantan, Handil Bakti, Barito Kuala', 'Handil Bakti, Barito Kuala'],
17: ['Jalan Guntung Manggis, Banjarbaru', 'Guntungmanggis, Banjarbaru'],
18: ['Kelayan Timur, Banjarmasin'],
19: ['Kalimantan Tengah, Indonesia'],  # Regional reference only; supplier province remains unknown.
20: ['Pasar Lima, Banjarmasin', 'Kertak Baru Ilir, Banjarmasin'],
21: ['Jalan Kalitanjung, Harjamukti, Cirebon', 'Harjamukti, Kota Cirebon'],
22: ['Karangsari, Waled, Cirebon', 'Waled, Cirebon'],
23: ['Dawuan, Kadipaten, Majalengka', 'Kadipaten, Majalengka'],
24: ['Rungkang, Kersana, Brebes', 'Kersana, Brebes'],
25: ['Pabedilan Kulon, Cirebon', 'Pabedilan, Cirebon'],
26: ['Mertasinga, Cirebon', 'Gunung Jati, Cirebon'],
27: ['Lau Cih, Sumatera Utara', 'Medan Tuntungan'],
28: ['Lau Cih, Sumatera Utara', 'Medan Tuntungan'],
29: ['Jalan Jamin Ginting, Medan'],
30: ['Medan, Sumatera Utara'],
31: ['Medan, Sumatera Utara'],
32: ['Tawangsari, Taman, Sidoarjo', 'Tawangsari, Sidoarjo'],
33: ['Kota Gajah, Lampung Tengah'],
34: ['Tejoagung, Metro, Lampung'],
35: ['Rajabasa Raya, Bandar Lampung'],
36: ['Jatimulyo, Lampung Selatan', 'Jati Mulyo, Lampung', 'Jati Agung'],
37: ['Pasir Gintung, Bandar Lampung'],
38: ['Pasar Panjang, Bandar Lampung', 'Panjang, Bandar Lampung'],
39: ['Silaberanti, Palembang'],
40: ['Palembang, Sumatera Selatan'],
41: ['Srijaya, Palembang'],
42: ['Sukarami, Palembang'],
43: ['Ilir Timur II, Palembang'],
44: ['Pasar Induk Jakabaring, Palembang', '15 Ulu, Palembang'],
}

def lookup(query):
    global last_request
    if query in cache:
        return cache[query]
    time.sleep(max(0, 1.15 - (time.monotonic() - last_request)))
    params = {'q': query, 'format': 'jsonv2', 'addressdetails': 1, 'limit': 3, 'accept-language': 'id'}
    if query != 'Borneo':
        params['countrycodes'] = 'id'
    url = 'https://nominatim.openstreetmap.org/search?' + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={'User-Agent': 'FolonyActivity-SupplierImport/1.0 (one-time 44 suppliers; https://staging-absent.folony.co.id)'})
    last_request = time.monotonic()
    with urllib.request.urlopen(request, timeout=30) as response:
        result = json.load(response)
    cache[query] = result
    CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding='utf-8')
    return result

output = []
for record in records:
    no = record['source_number']
    candidates = []
    used = None
    for query in queries[no]:
        candidates = lookup(query)
        if no == 36:
            candidates = [p for p in candidates if any(n in p.get('name', '').casefold() for n in ['jatimulyo', 'jati mulyo', 'jati agung'])]
        if candidates:
            used = query
            break
    if not candidates:
        print(f'{no}: NO MATCH', flush=True)
        output.append({**record, 'coordinate_status': 'unresolved'})
        continue
    point = candidates[0]
    lat, lon = float(point['lat']), float(point['lon'])
    full_code = None
    if record['plus_codes']:
        full_code = olc.recoverNearest(record['plus_codes'][0], lat, lon)
        area = olc.decode(full_code)
        lat, lon = area.latitudeCenter, area.longitudeCenter
    assert -11.5 <= lat <= 6.5 and 94 <= lon <= 142, (no, lat, lon)
    address = point.get('address', {})
    output.append({**record,
        'latitude': round(lat, 7), 'longitude': round(lon, 7),
        'coordinate_status': 'plus_code' if full_code else ('regional_reference' if no == 19 else 'approximate'),
        'full_plus_code': full_code, 'geocode_query': used, 'geocode_match': point['display_name'],
        'geocode_type': point.get('addresstype'), 'geocode_osm_type': point.get('osm_type'), 'geocode_osm_id': point.get('osm_id'),
        'territory_province': None if no == 19 else ('DKI Jakarta' if address.get('ISO3166-2-lvl4') == 'ID-JK' else address.get('state')),
        'territory_city': None if no == 19 else ((address.get('city_district') if address.get('city') == 'Daerah Khusus Ibukota Jakarta' else address.get('city')) or address.get('county') or address.get('town')),
        'territory_district': None if no == 19 else (address.get('suburb') or address.get('municipality') or address.get('district') or address.get('city_district')),
        'geocode_candidates': [{'name': p['display_name'], 'lat': p['lat'], 'lon': p['lon']} for p in candidates],
    })
    print(f'{no}: {"PLUS CODE" if full_code else "APPROX"} {lat:.7f}, {lon:.7f} | {point["display_name"]}', flush=True)
    (OUT / 'suppliers-geocoded.json').write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding='utf-8')
(OUT / 'suppliers-geocoded.json').write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'Prepared {len(output)} suppliers; unresolved {sum(r["coordinate_status"] == "unresolved" for r in output)}', flush=True)
