/// Only removes contact information; house numbers, RT/RW and postal codes stay.
String fggDirectionsAddress(String raw,
    {String customerName = '', String phoneNumber = ''}) {
  var address = raw
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll('\r', '\n');
  // FGG format: recipient/business name (phone number) delivery address.
  final contactPrefix = RegExp(
          r'^\s*([^\n()]*)\(\s*(?:\+?62|0)[0-9 .-]{7,}\s*\)\s*(.+)$',
          dotAll: true)
      .firstMatch(address);
  if (contactPrefix != null &&
      !RegExp(r'\b(?:jl|jalan|gang|gg|rt|rw|no)\b', caseSensitive: false)
          .hasMatch(contactPrefix.group(1)!)) {
    address = contactPrefix.group(2)!;
  }
  final name = customerName.trim();
  if (name.isNotEmpty) {
    final escaped = RegExp.escape(name);
    address = address.replaceAll(
        RegExp(
            '(^|[\\n|;])\\s*(?:(?:nama|penerima|recipient|customer)\\s*:\\s*)?$escaped(?=\\s*[,|;\\n-]|\\s+(?:08|\\+?62|Jl\\.?|Jalan)\\b|\\s*\$)',
            caseSensitive: false),
        '\n');
    // Names preceding a comma are common in the supplied delivery-address field.
    address = address.replaceFirst(
        RegExp('^\\s*$escaped\\s*,\\s*', caseSensitive: false), '');
  }
  final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 9) {
    final pattern = digits.split('').map(RegExp.escape).join(r'[\s().-]*');
    address = address.replaceAll(RegExp('(?<![0-9])\\+?$pattern(?![0-9])'), '');
  }
  address = address
      .replaceAll(
          RegExp(
              r'(?<![0-9])(?:\+62|62|08)[ .()-]*[0-9](?:[ .()-]*[0-9]){7,11}(?![0-9])'),
          '')
      .replaceAll(
          RegExp(
              r'\b(?:telp(?:on)?|telepon|phone|no\.?\s*(?:hp|telp)|hp|whatsapp|wa)\s*:?\s*(?:\+?[0-9][0-9 ()-]{7,}[0-9])?',
              caseSensitive: false),
          '')
      .replaceAll(
          RegExp(
              r'(^|[\n|;])\s*(?:nama(?:\s+penerima)?|penerima|recipient|customer)\s*:[^,\n|;]*?(?=,|\n|\||;|$)',
              caseSensitive: false),
          '\n')
      .replaceAll(
          RegExp(
              r'(^|[\n|;])\s*(?:alamat(?:\s+(?:pengiriman|penerima|tujuan))?|address)\s*:\s*',
              caseSensitive: false),
          '\n');
  address = address.replaceAll(RegExp(r'\(\s*\)'), '');
  return address
      .split(RegExp(r'[\n|;]+'))
      .map((part) => part.trim().replaceAll(RegExp(r'^[\s,:-]+|[\s,:-]+$'), ''))
      .where((part) => part.isNotEmpty)
      .join(', ')
      .replaceAll(RegExp(r'\s*,\s*(?:,\s*)+'), ', ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
