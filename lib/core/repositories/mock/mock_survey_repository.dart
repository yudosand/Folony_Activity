import '../../models/survey_models.dart';
import '../survey_repository.dart';

class MockSurveyRepository implements SurveyRepository {
  final List<KioskSurveySubmission> kioskSurveys = [];
  final List<PriceSurveySubmission> priceSurveys = [];

  @override
  Future<SurveyOptions> loadOptions() async {
    return SurveyOptions.fallback;
  }

  @override
  Future<void> submitKioskSurvey(KioskSurveySubmission submission) async {
    kioskSurveys.insert(0, submission);
  }

  @override
  Future<void> submitPriceSurvey(PriceSurveySubmission submission) async {
    priceSurveys.insert(0, submission);
  }
}
