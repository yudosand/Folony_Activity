import 'package:flutter_test/flutter_test.dart';
import 'package:folony_activity/core/models/remote_attachment.dart';
import 'package:folony_activity/core/models/survey_models.dart';
import 'package:folony_activity/core/repositories/mock/mock_survey_repository.dart';

void main() {
  test('SurveyOptions parses products and commodities from API payload', () {
    final options = SurveyOptions.fromJson({
      'products': [
        {'id': 'prod_1', 'name': 'Beras'},
      ],
      'commodities': [
        {'id': 'cmd_1', 'name': 'Cabai', 'unit': 'kg'},
      ],
      'building_types': ['Permanen'],
      'kiosk_sizes': ['3 - 10 m2'],
    });

    expect(options.products.single.name, 'Beras');
    expect(options.commodities.single.unit, 'kg');
    expect(options.buildingTypes.single, 'Permanen');
    expect(options.kioskSizes.single, '3 - 10 m2');
  });

  test('MockSurveyRepository stores kiosk and price submissions', () async {
    final repository = MockSurveyRepository();
    const attachment = RemoteAttachment(
      id: 'photo_1',
      fileName: 'survey.jpg',
      mimeType: 'image/jpeg',
      url: 'https://example.test/storage/survey.jpg',
    );

    await repository.submitKioskSurvey(
      const KioskSurveySubmission(
        photo: attachment,
        territoryProvince: 'Jawa Barat',
        territoryCity: 'Indramayu',
        territoryDistrict: 'Indramayu',
        territorySubdistrict: 'Karanganyar',
        kioskName: 'Warung Jable',
        phoneNumber: '081200000000',
        ownerName: 'Jable',
        productIds: ['prod_1'],
        otherProduct: '',
        buildingTypes: ['Permanen'],
        kioskSizes: ['3 - 10 m2'],
      ),
    );

    await repository.submitPriceSurvey(
      const PriceSurveySubmission(
        photo: attachment,
        marketName: 'Pasar Indramayu',
        territoryProvince: 'Jawa Barat',
        territoryCity: 'Indramayu',
        territoryDistrict: 'Indramayu',
        territorySubdistrict: 'Karanganyar',
        commodityPrices: [
          CommodityPriceSubmission(
            commodityId: 'cmd_1',
            commodityName: 'Cabai',
            unit: 'kg',
            lowestPrice: 22000,
            highestPrice: 25000,
          ),
        ],
      ),
    );

    expect(repository.kioskSurveys.single.kioskName, 'Warung Jable');
    expect(
      repository.priceSurveys.single.commodityPrices.single.lowestPrice,
      22000,
    );
    expect(
      repository.priceSurveys.single.commodityPrices.single.highestPrice,
      25000,
    );
  });
}
