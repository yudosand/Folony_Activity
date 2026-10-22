import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_controller.dart';
import '../../../core/models/supplier.dart';
import '../../../core/network/human_readable_error.dart';
import 'supplier_form_page.dart';

class SupplierPage extends StatefulWidget {
  const SupplierPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<SupplierPage> createState() => _SupplierPageState();
}

class _SupplierPageState extends State<SupplierPage> {
  final _items = <Supplier>[];
  bool _loading = false, _hasMore = false;
  int _page = 0, _total = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    final repository = widget.controller.supplierRepository;
    if (repository == null) {
      setState(() => _error =
          'Supplier membutuhkan koneksi backend. Gunakan akun pada aplikasi staging.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final next = reset ? 1 : _page + 1;
      final result = await repository.list(page: next);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        final ids = _items.map((s) => s.id).toSet();
        _items.addAll(result.items.where((s) => ids.add(s.id)));
        _hasMore = result.hasMore;
        _total = result.total;
        _page = next;
      });
    } catch (error) {
      if (mounted) {
        setState(() =>
            _error = humanReadableError(error, action: 'memuat supplier'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => SupplierFormPage(controller: widget.controller)));
    if (added == true && mounted) await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Text('Supplier yang saya tambahkan',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('$_total supplier • Hanya data yang dibuat oleh akun Anda.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                  onPressed: _loading ? null : _add,
                  icon: const Icon(Icons.add_business),
                  label: const Text('Tambah Supplier')),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                TextButton(
                    onPressed: _loading ? null : () => _load(reset: _page == 0),
                    child: const Text('Coba lagi')),
              ],
              if (_items.isEmpty && !_loading && _error == null)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                        'Belum ada supplier. Tambahkan supplier pertama Anda.')),
              for (final supplier in _items)
                Card(
                    child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(supplier.name),
                  subtitle: Text(
                      '${[
                        supplier.city,
                        supplier.province
                      ].where((s) => s.isNotEmpty).join(', ')}\n${supplier.items.join(', ')}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _SupplierDetail(supplier: supplier))),
                )),
              if (_loading)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator())),
              if (_hasMore && !_loading)
                OutlinedButton(
                    onPressed: _load,
                    child: const Text('Muat supplier berikutnya')),
            ]),
      );
}

class _SupplierDetail extends StatelessWidget {
  const _SupplierDetail({required this.supplier});
  final Supplier supplier;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Detail Supplier')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(supplier.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          _row(context, 'Nama PIC supplier', supplier.picName ?? 'Belum diisi'),
          _row(context, 'No. HP', supplier.phoneNumber),
          _row(
              context,
              'Wilayah',
              [supplier.province, supplier.city, supplier.district]
                  .where((s) => s.isNotEmpty)
                  .join(' / ')),
          _row(
              context,
              'Alamat',
              supplier.address.isEmpty
                  ? 'Menggunakan titik lokasi'
                  : supplier.address),
          _row(context, 'Jenis kebutuhan', supplier.items.join('\n')),
          _row(context, 'Keterangan / Catatan',
              supplier.notes?.isNotEmpty == true ? supplier.notes! : '—'),
          if (supplier.createdAt != null)
            _row(context, 'Ditambahkan', _dateLabel(supplier.createdAt!)),
          if (supplier.latitude != null && supplier.longitude != null) ...[
            _row(context, 'Titik lokasi',
                '${supplier.latitude}, ${supplier.longitude}'),
            OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final ok = await launchUrl(
                        Uri.https('www.google.com', '/maps/search/', {
                          'api': '1',
                          'query': '${supplier.latitude},${supplier.longitude}'
                        }),
                        mode: LaunchMode.externalApplication);
                    if (!ok) throw StateError('maps');
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Google Maps belum bisa dibuka.')));
                    }
                  }
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text('Buka Google Maps')),
          ] else
            const Text('Alamat manual, belum memiliki titik peta.'),
        ]),
      );

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  Widget _row(BuildContext context, String label, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          SelectableText(text),
        ]),
      );
}
