import '../../models/announcement.dart';
import '../announcement_repository.dart';

class MockAnnouncementRepository implements AnnouncementRepository {
  const MockAnnouncementRepository();

  @override
  Future<List<Announcement>> listActive() async {
    return [
      Announcement(
        id: 'ann_demo_001',
        title: 'Selamat bekerja',
        body:
            'Jangan lupa absen sesuai jadwal dan lengkapi aktivitas hari ini.',
        publishedAt: DateTime.now(),
      ),
    ];
  }
}
