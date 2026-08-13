import '../models/survey_models.dart';

abstract class SurveyRepository {
  Future<SurveyOptions> loadOptions();

  Future<void> submitKioskSurvey(KioskSurveySubmission submission);

  Future<void> submitPriceSurvey(PriceSurveySubmission submission);
}
