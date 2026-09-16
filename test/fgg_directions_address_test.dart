import 'package:flutter_test/flutter_test.dart';
import 'package:folony_activity/core/services/fgg_directions_address.dart';

void main() {
  test(
      'cleans actual FGG name (phone) address format even without separate name',
      () {
    expect(
        fggDirectionsAddress(
            'bakso wafa (0812345678001) masjid al makmur, Kota Jakarta Selatan - DKI Jakarta'),
        'masjid al makmur, Kota Jakarta Selatan - DKI Jakarta');
  });
  test('strips contact lines and preserves house, RT/RW and postal code', () {
    expect(
        fggDirectionsAddress(
            'Nama: Nadia\nHP: 081234567890\nAlamat: Jl. Mawar No. 12, RT 003/RW 004, Jakarta 10140',
            customerName: 'Nadia',
            phoneNumber: '081234567890'),
        'Jl. Mawar No. 12, RT 003/RW 004, Jakarta 10140');
  });
  test('cleans comma separated recipient and phone', () {
    expect(
        fggDirectionsAddress('Nadia, 081234567890, Jl. Mawar No. 12, Jakarta',
            customerName: 'Nadia'),
        'Jl. Mawar No. 12, Jakarta');
  });
  test('strips formatted international phone and HTML breaks', () {
    expect(
        fggDirectionsAddress(
            'Nadia<br>+62 812-3456-7890<br/>Perum Indah Blok B-12, Bandung 40123',
            customerName: 'Nadia'),
        'Perum Indah Blok B-12, Bandung 40123');
  });
  test(
      'does not remove person names embedded in road names or ordinary address numbers',
      () {
    const address = 'Jalan Ahmad Yani No. 62, RT 08/RW 02, Blok A-12, 40123';
    expect(fggDirectionsAddress(address, customerName: 'Ahmad Yani'), address);
  });
  test('contact-only input does not become a fake destination', () {
    expect(
        fggDirectionsAddress('Nadia\n081234567890', customerName: 'Nadia'), '');
  });
}
