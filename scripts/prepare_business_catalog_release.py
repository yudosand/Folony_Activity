"""Package the complete staging backend and APK without server data or secrets."""
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED
import hashlib,json,shutil
root=Path(__file__).resolve().parents[1]
backend=root/'backend'
out=root/'dist/business-catalog-staging-2026-10-22'
out.mkdir(parents=True,exist_ok=True)
archive_path=out/'FolonyActivity-FULL-STAGING-Jenis-Usaha-20261022.zip'
files={}
for folder in ['app','bootstrap','config','database/migrations','database/seeders','database/factories','database/data','public','resources','routes','vendor']:
 for path in (backend/folder).rglob('*'):
  if not path.is_file() or path.is_symlink(): continue
  rel=path.relative_to(backend).as_posix()
  if rel.startswith(('public/storage/','bootstrap/cache/')): continue
  if any(p.startswith('.env') or p=='.git' for p in path.relative_to(backend).parts):continue
  if rel.startswith('public/') and path.suffix=='.php' and rel!='public/index.php':continue
  files[rel]=path.read_bytes()
for name in ['artisan','composer.json','composer.lock','package.json','vite.config.js']: files[name]=(backend/name).read_bytes()
guide='''FOLONY ACTIVITY — FULL BACKEND STAGING JENIS USAHA
Paket flat: extract langsung ke root Laravel staging. Semua kode aplikasi dan vendor disertakan.
Pertahankan .env, APP_KEY dan storage server. Jangan gunakan migrate:fresh atau menghapus data lama.
Backup kode dan database staging dahulu. Production tidak termasuk uji ini.
SSH root: /home/folony-staging-absent/htdocs/staging-absent.folony.co.id
Setelah menyalin kode, jalankan:
php artisan migrate --force
php artisan business:bootstrap
php artisan business:bootstrap --apply
php artisan optimize:clear
php artisan view:cache
Pemetaan hanya mengisi business_kind_id yang masih kosong; teks asal dan koordinat tidak diubah.
Perintah bootstrap membatasi host ke staging-absent.folony.co.id dan menyimpan backup privat.
Di staging saat ini migrasi dan pemetaan sudah dijalankan, tidak perlu deploy ulang untuk mencoba.
HR: /admin/business-catalog untuk master dan peninjauan; /admin/network untuk peta/filter.
APK pasangan: 0.1.15 / 20261024, backend staging, instal langsung tanpa menghapus data aplikasi.
'''
files['STAGING-JENIS-USAHA.txt']=guide.encode()
files['FILE-MANIFEST.sha256']=''.join(f'{hashlib.sha256(data).hexdigest()}  {name}\n' for name,data in sorted(files.items())).encode()
with ZipFile(archive_path,'w',ZIP_DEFLATED,compresslevel=6) as z:
 for name,data in sorted(files.items()):
  info=ZipInfo(name);info.create_system=3;info.external_attr=0o100644<<16;info.compress_type=ZIP_DEFLATED;z.writestr(info,data)
 for name in ['bootstrap/cache/','storage/app/private/','storage/app/public/','storage/framework/cache/data/','storage/framework/sessions/','storage/framework/views/','storage/logs/']:
  info=ZipInfo(name);info.create_system=3;info.external_attr=(0o40775<<16)|0x10;z.writestr(info,b'')
with ZipFile(archive_path) as z:
 assert z.testzip() is None
 for name,data in files.items():assert z.read(name)==data,name
 assert 'database/data/business-catalog.json' in z.namelist()
apk=out/'FolonyActivity-STAGING-Jenis-Usaha-0.1.15.apk'
shutil.copy2(root/'build/app/outputs/flutter-apk/app-release.apk',apk)
with ZipFile(apk) as z:
 binary=z.read('lib/arm64-v8a/libapp.so')
 for value in [b'staging-absent.folony.co.id',b'/business-catalog',b'business_kind_id']:
  assert value in binary,value
report={'backend_files_verified':len(files),'crc_passed':True,'flat_root':True,'apk_contains_staging_and_catalog':True,
 'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [archive_path,apk]}}
(out/'verification.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
(out/'PANDUAN-STAGING.txt').write_text(guide,encoding='utf-8')
print(json.dumps(report,indent=2))
