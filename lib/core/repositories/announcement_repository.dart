import '../models/announcement.dart';

abstract class AnnouncementRepository {
  Future<List<Announcement>> listActive();
}
