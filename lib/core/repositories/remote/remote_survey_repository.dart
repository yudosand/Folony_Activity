import '../../models/survey_models.dart';
import '../../network/simple_api_client.dart';
import '../survey_repository.dart';

class RemoteSurveyRepository implements SurveyRepository {
  const RemoteSurveyRepository({
    required SimpleApiClient client,
  }) : _client = client;

  final SimpleApiClient _client;

  @override
  Future<SurveyOptions> loadOptions() async {
    final response = await _client.get('/surveys/options');
    final data = _unwrapMap(response);
    final options = SurveyOptions.fromJson(data);
    if (options.products.isEmpty && options.commodities.isEmpty) {
      return SurveyOptions.fallback;
    }
    return SurveyOptions(
      products: options.products.isEmpty
          ? SurveyOptions.fallback.products
          : options.products,
      commodities: options.commodities.isEmpty
          ? SurveyOptions.fallback.commodities
          : options.commodities,
      buildingTypes: options.buildingTypes.isEmpty
          ? SurveyOptions.fallback.buildingTypes
          : options.buildingTypes,
      kioskSizes: options.kioskSizes.isEmpty
          ? SurveyOptions.fallback.kioskSizes
          : options.kioskSizes,
    );
  }

  @override
  Future<void> submitKioskSurvey(KioskSurveySubmission submission) async {
    await _client.post('/surveys/kios', body: submission.toJson());
  }

  @override
  Future<void> submitPriceSurvey(PriceSurveySubmission submission) async {
    await _client.post('/surveys/prices', body: submission.toJson());
  }

  Map<String, dynamic> _unwrapMap(dynamic response) {
    if (response is Map<String, dynamic>) {
      if (response['data'] is Map) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
      return response;
    }
    if (response is Map) {
      if (response['data'] is Map) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
      return Map<String, dynamic>.from(response);
    }
    return const {};
  }
}
