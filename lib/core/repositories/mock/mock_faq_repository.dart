import '../../models/faq_item.dart';
import '../faq_repository.dart';

class MockFaqRepository implements FaqRepository {
  const MockFaqRepository();

  @override
  Future<List<FaqItem>> listActive() async {
    return const [
      FaqItem(
        id: 'faq_absensi',
        title: 'Cara Absensi',
        body:
            '1. Buka menu Absensi.\n2. Pastikan lokasi aktif dan berada di area kerja.\n3. Daftarkan wajah jika belum pernah.\n4. Saat scan, lihat ke kamera dan pastikan cahaya cukup.\n5. Tekan check-in atau check-out setelah verifikasi berhasil.',
      ),
      FaqItem(
        id: 'faq_jaringan',
        title: 'Cara Tambah UKM atau Mitra',
        body:
            'Buka menu Jaringan, tekan tombol tambah, pilih UKM atau Mitra, isi data lokasi dari GPS atau manual, ambil foto dari kamera, lalu simpan.',
      ),
    ];
  }
}
