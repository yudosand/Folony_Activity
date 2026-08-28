import '../models/faq_item.dart';

abstract class FaqRepository {
  Future<List<FaqItem>> listActive();
}
