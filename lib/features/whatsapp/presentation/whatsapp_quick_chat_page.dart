import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppQuickChatPage extends StatefulWidget {
  const WhatsAppQuickChatPage({super.key});

  @override
  State<WhatsAppQuickChatPage> createState() => _WhatsAppQuickChatPageState();
}

class _WhatsAppQuickChatPageState extends State<WhatsAppQuickChatPage> {
  final _phoneController = TextEditingController();
  bool _isOpening = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Kirim WhatsApp',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Masukkan nomor tujuan, lalu buka chat WhatsApp tanpa perlu menyimpan kontak.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE7E5E4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor WhatsApp',
                  hintText: 'Contoh: 081234567890',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isOpening ? null : _openWhatsApp,
                  icon: const Icon(Icons.chat_rounded),
                  label: Text(_isOpening ? 'Membuka...' : 'Buka WhatsApp'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openWhatsApp() async {
    final phone = _normalizePhone(_phoneController.text);
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor WhatsApp belum valid.')),
      );
      return;
    }

    setState(() => _isOpening = true);
    try {
      final uri = Uri.parse('https://wa.me/$phone');
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp tidak bisa dibuka di perangkat ini.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  String? _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) {
      return null;
    }
    if (digits.startsWith('+')) {
      final withoutPlus = digits.substring(1);
      return withoutPlus.length >= 8 ? withoutPlus : null;
    }
    if (digits.startsWith('0')) {
      final national = digits.substring(1);
      return national.length >= 8 ? '62$national' : null;
    }
    if (digits.startsWith('62')) {
      return digits.length >= 10 ? digits : null;
    }
    return digits.length >= 8 ? '62$digits' : null;
  }
}
