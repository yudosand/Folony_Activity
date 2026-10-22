"""Build a flat, complete staging backend bundle; preserve server data on deploy."""
from pathlib import Path
import hashlib
import json
import secrets
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / 'backend'
OUT = ROOT / 'dist' / 'supplier-staging-2026-10-22-v2'
OUT.mkdir(parents=True, exist_ok=True)
ZIP = OUT / 'FolonyActivity-FULL-STAGING-Supplier-2026-10-22-v2.zip'
if ZIP.exists():
    raise SystemExit('Package already exists; use a new release name.')

files = {}
for folder in ['app', 'bootstrap', 'config', 'database/migrations', 'database/seeders',
               'database/factories', 'public', 'resources', 'routes', 'vendor']:
    for path in (BACKEND / folder).rglob('*'):
        if not path.is_file() or path.is_symlink():
            continue
        rel = path.relative_to(BACKEND).as_posix()
        if rel.startswith('public/storage/') or rel.startswith('bootstrap/cache/'):
            continue
        if any(p.startswith('.env') or p == '.git' for p in path.relative_to(BACKEND).parts):
            continue
        if rel.startswith('public/') and path.suffix == '.php' and any(word in path.name.lower() for word in ['once', 'diagnos', 'setup', 'seed-demo']):
            continue
        files[rel] = path.read_bytes()
for name in ['artisan', 'composer.json', 'composer.lock', 'package.json', 'vite.config.js']:
    files[name] = (BACKEND / name).read_bytes()

release = 'supplier-20261022-v2'
token = secrets.token_hex(24)
helper_name = f'staging-artisan-once-{release}.php'
helper = (ROOT / 'scripts/templates/staging-artisan-once.php.template').read_text(encoding='utf-8')
files['public/' + helper_name] = helper.replace('__DEPLOY_TOKEN__', token).replace('__DEPLOY_RELEASE__', release).encode()
helper_url = f'https://staging-absent.folony.co.id/{helper_name}?token={token}'
guide = f'''FOLONY ACTIVITY — SUPPLIER STAGING V2 — 22 Oktober 2026

Hanya untuk staging-absent.folony.co.id. Paket ini full backend + vendor,
dengan isi langsung pada root ZIP (tanpa folder pembungkus).
Kode staging lokal termasuk perubahan Supplier yang belum di-commit.

1. Backup kode, database, .env dan storage staging.
2. Extract langsung ke root Laravel staging, sejajar dengan .env:
   /home/folony-staging-absent/htdocs/staging-absent.folony.co.id
   Pertahankan .env dan seluruh isi storage. Jangan hapus APP_KEY.
   Jangan gunakan migrate:fresh atau db:seed. Pastikan file bukan bernama *_copy.
3. Pastikan APP_URL=https://staging-absent.folony.co.id dan FGG_ENVIRONMENT=staging.
   Document root tetap public; storage dan bootstrap/cache harus writable.
4. Jalankan migrasi dan clear cache melalui SSH:
   php artisan optimize:clear
   php artisan migrate --force
   php artisan storage:link  (jika link belum ada)
   ATAU buka link privat ini dan tekan Jalankan Artisan Staging:
   {helper_url}
   Helper memeriksa host/environment dan menghapus dirinya setelah berhasil.
5. Logout dari APK lama sebelum pindah environment. Instal APK staging pasangan
   paket ini. Application ID sama dengan APK sebelumnya sehingga menggantikannya.
6. Uji SPV, Management, Area Manager: Tambah Supplier + Supplier yang saya tambahkan.
   Akun berbeda tidak boleh melihat supplier akun lain.
   Form aplikasi: nama PIC supplier wajib, berbeda dengan PIC pembuat dari login.
   Setelah memilih GPS/peta, wilayah manual tidak muncul dan tidak wajib diisi.
   HR: Daftar Supplier menampilkan semuanya, kedua PIC, filter wilayah dan peta.
   Filter Kebutuhan / Barang mencari sebagian nama barang di tabel sekaligus peta.
   Alamat manual tanpa koordinat tersimpan di tabel, belum menjadi titik peta.

Paket ini tidak membawa .env, database, upload lama atau cache server lokal.
Vendor dari workspace disertakan lengkap (termasuk dependency pengembangan staging).
Migrasi 000001 membuat tabel suppliers jika belum ada. Migrasi 000002 menambah
pic_name dan mengizinkan alamat/wilayah kosong untuk GPS. Data lama dipertahankan.
PENTING: deploy ZIP ini dan jalankan migrate sebelum memakai form APK terbaru.
APK pasangan: 0.1.14 / 20261023, ARM64, backend STAGING_VPS.
Distribusi APK: instal langsung. Deployment server dilakukan terpisah.
Tidak ada perubahan pada production.
'''
files['STAGING-SUPPLIER-DEPLOY.txt'] = guide.encode()
manifest = ''.join(f'{hashlib.sha256(data).hexdigest()}  {name}\n' for name, data in sorted(files.items()))
files['FILE-MANIFEST.sha256'] = manifest.encode()
with ZipFile(ZIP, 'w', ZIP_DEFLATED, compresslevel=6) as archive:
    for name, data in sorted(files.items()):
        info = ZipInfo(name)
        info.compress_type = ZIP_DEFLATED
        info.create_system = 3
        info.external_attr = 0o100644 << 16
        archive.writestr(info, data)
    for name in ['bootstrap/cache/', 'storage/app/private/', 'storage/app/public/',
                 'storage/framework/cache/data/', 'storage/framework/sessions/',
                 'storage/framework/views/', 'storage/logs/']:
        info = ZipInfo(name)
        info.create_system = 3
        info.external_attr = (0o40775 << 16) | 0x10
        archive.writestr(info, b'')
with ZipFile(ZIP) as archive:
    assert archive.testzip() is None
    for name, data in files.items():
        assert archive.read(name) == data, name
    for name in ['artisan', 'vendor/autoload.php', 'public/index.php', 'public/.htaccess',
                 'app/Models/Supplier.php', 'database/migrations/2026_10_22_000001_create_suppliers_table.php',
                 'database/migrations/2026_10_22_000002_add_supplier_pic_and_optional_gps_address.php']:
        assert name in archive.namelist(), name
(OUT / 'PANDUAN-DEPLOY-STAGING.txt').write_text(guide, encoding='utf-8')
(OUT / 'BACKEND-SHA256.txt').write_text(hashlib.sha256(ZIP.read_bytes()).hexdigest() + '  ' + ZIP.name + '\n', encoding='utf-8')
(OUT / 'package-verification.json').write_text(json.dumps({'files_verified': len(files), 'crc_passed': True,
    'flat_root': True, 'environment': 'staging', 'contains_server_env_or_data': False}, indent=2), encoding='utf-8')
print(f'Verified {len(files)} files. Package: {ZIP}')
