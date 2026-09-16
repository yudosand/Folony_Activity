import 'package:flutter/material.dart';
import '../../../core/repositories/fgg_repository.dart';
import '../../../core/network/human_readable_error.dart';
import 'fgg_shipping_page.dart';

class FggSummaryCard extends StatefulWidget {
  const FggSummaryCard({super.key, required this.repository});
  final FggRepository repository;
  @override
  State<FggSummaryCard> createState() => FggSummaryCardState();
}

class FggSummaryCardState extends State<FggSummaryCard> {
  Map<String, int>? _counts;
  String? _error;
  bool _busy = false;
  bool _linked = false;
  @override
  void initState() {
    super.initState();
    widget.repository.addListener(refresh);
    refresh();
  }

  @override
  void dispose() {
    widget.repository.removeListener(refresh);
    super.dispose();
  }

  Future<void> refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _counts = null;
    });
    try {
      final session = await widget.repository.session();
      _linked = session['connected'] == true && session['hub_id'] != null;
      if (_linked) _counts = await widget.repository.shippingSummary();
    } catch (e) {
      _error = e is StateError
          ? e.message
          : humanReadableError(e, action: 'menghitung seluruh riwayat kiriman');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => FggShippingPage(repository: widget.repository)));
    if (mounted) await refresh();
  }

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                  child: Text('Dashboard Kiriman',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
              IconButton(
                  tooltip: 'Perbarui jumlah kiriman',
                  onPressed: _busy ? null : refresh,
                  icon: const Icon(Icons.refresh))
            ]),
            if (_busy) const LinearProgressIndicator(),
            if (_busy)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Menghitung seluruh halaman riwayat…')),
            if (_error != null) Text(_error!),
            if (!_busy && _error == null && !_linked)
              const Text(
                  'Hubungkan dan pilih akun HUB untuk melihat ringkasan kiriman.'),
            if (_counts != null)
              Row(children: [
                Expanded(
                    child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${_counts!['pending']}',
                            style: Theme.of(context).textTheme.headlineMedium),
                        subtitle: const Text('Belum dikirim'))),
                Expanded(
                    child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${_counts!['sent']}',
                            style: Theme.of(context).textTheme.headlineMedium),
                        subtitle: const Text('Sudah dikirim'))),
              ]),
            const Text('Total seluruh riwayat akun HUB, tanpa batas bulan.'),
            TextButton(
                onPressed: _open,
                child: Text(_linked ? 'Buka kiriman' : 'Hubungkan akun FGG')),
          ])));
}
