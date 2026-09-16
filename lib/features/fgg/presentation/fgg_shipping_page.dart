import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fgg_trip_panel.dart';

import '../../../core/repositories/fgg_repository.dart';
import '../../../core/network/human_readable_error.dart';
import '../../../core/network/simple_api_client.dart';

String _fggError(Object error) => error is ApiException
    ? error.message
    : error is StateError
        ? error.message
        : humanReadableError(error, action: 'mengakses FGG');

class FggShippingPage extends StatefulWidget {
  const FggShippingPage({super.key, required this.repository});
  final FggRepository repository;

  @override
  State<FggShippingPage> createState() => _FggShippingPageState();
}

class _FggShippingPageState extends State<FggShippingPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _search = TextEditingController();
  Map<String, dynamic>? _session;
  List<Map<String, dynamic>> _rows = [];
  String _kind = 'dst';
  int _status = 1;
  int _page = 1;
  int _totalPages = 1;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run(() async {
      _session = await widget.repository.session();
      if (_selected) await _load();
    });
  }

  bool get _selected =>
      _session?['connected'] == true && _session?['hub_id'] != null;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) _error = _fggError(e);
      if (e is ApiException && e.statusCode == 409) {
        try {
          _session = await widget.repository.session();
        } catch (_) {}
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    final result = await widget.repository
        .list(_kind, search: _search.text.trim(), status: _status, page: _page);
    _rows = (result['data'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    _totalPages = max(1, (result['total_pages'] as num).toInt());
  }

  Future<void> _connect() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      throw StateError('Isi akun dan kata sandi FGG.');
    }
    final prefs = await SharedPreferences.getInstance();
    var device = prefs.getString('fgg_device_id');
    if (device == null) {
      device = List.generate(
          24,
          (_) => Random.secure()
              .nextInt(256)
              .toRadixString(16)
              .padLeft(2, '0')).join();
      await prefs.setString('fgg_device_id', device);
    }
    _session = await widget.repository.connect({
      'fuserid': _username.text.trim(),
      'fpassword': _password.text,
      'idDevice': device,
      'os_version': Platform.operatingSystemVersion,
    });
    _password.clear();
    _rows = [];
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FGG Pengiriman'), actions: [
        if (_session?['connected'] == true)
          IconButton(
              tooltip: 'Putuskan akun FGG',
              onPressed: _busy
                  ? null
                  : () async {
                      final confirmed = await _confirm('Putuskan akun FGG?',
                          'Anda perlu login FGG kembali untuk membuka pengiriman.');
                      if (confirmed && mounted) {
                        await _run(() async {
                          await widget.repository.disconnect();
                          _session = await widget.repository.session();
                          _rows = [];
                        });
                      }
                    },
              icon: const Icon(Icons.link_off)),
      ]),
      body: Column(children: [
        if (_busy) const LinearProgressIndicator(),
        Expanded(
            child: RefreshIndicator(
          onRefresh: () => _run(() async {
            _session = await widget.repository.session();
            if (_selected) await _load();
          }),
          child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_session?['environment'] == 'staging')
                  const Chip(label: Text('FGG Staging')),
                if (_error != null)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_error!,
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.error)))),
                if (_session == null && !_busy)
                  OutlinedButton(
                      onPressed: () => _run(() async {
                            _session = await widget.repository.session();
                            if (_selected) await _load();
                          }),
                      child: const Text('Coba lagi')),
                if (_session != null && _session?['connected'] != true) ...[
                  Text('Hubungkan Akun FGG',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Gunakan akun FGG yang memiliki akses HUB.'),
                  const SizedBox(height: 20),
                  TextField(
                      controller: _username,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                          labelText: 'Akun FGG / nomor HP')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration:
                          const InputDecoration(labelText: 'Kata sandi FGG')),
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: _busy ? null : () => _run(_connect),
                      child: const Text('Hubungkan')),
                ] else if (_session?['connected'] == true && !_selected) ...[
                  Text('Pilih Akun HUB',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  for (final hub in (_session?['hubs'] as List? ?? []))
                    Card(
                        child: ListTile(
                            title: Text('${hub['name']}'),
                            subtitle: Text('${hub['id']}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _busy
                                ? null
                                : () => _run(() async {
                                      _session = await widget.repository
                                          .selectHub('${hub['id']}');
                                      _page = 1;
                                      await _load();
                                    }))),
                ] else if (_selected) ...[
                  Text('${_session!['name']} · ${_session!['hub_id']}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'dst', label: Text('Terima DST')),
                        ButtonSegment(
                            value: 'shipments', label: Text('Kiriman')),
                      ],
                      selected: {
                        _kind
                      },
                      onSelectionChanged: _busy
                          ? null
                          : (value) => _run(() async {
                                _kind = value.first;
                                _page = 1;
                                _status = 1;
                                _search.clear();
                                _rows = [];
                                await _load();
                              })),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _search,
                      enabled: !_busy,
                      decoration: InputDecoration(
                          labelText: 'Cari pengiriman',
                          suffixIcon: IconButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                        _page = 1;
                                        await _load();
                                      }),
                              icon: const Icon(Icons.search))),
                      onSubmitted: (_) => _run(() async {
                            _page = 1;
                            await _load();
                          })),
                  DropdownButton<int>(
                      key: ValueKey('$_kind-status'),
                      isExpanded: true,
                      value: _status,
                      items: _kind == 'dst'
                          ? const [
                              DropdownMenuItem(
                                  value: 1, child: Text('Bisa diterima')),
                              DropdownMenuItem(
                                  value: 2, child: Text('Sudah diterima')),
                              DropdownMenuItem(
                                  value: 0, child: Text('Semua status')),
                            ]
                          : const [
                              DropdownMenuItem(
                                  value: 1, child: Text('Siap dikirim')),
                              DropdownMenuItem(
                                  value: 2, child: Text('Sudah dikirim')),
                            ],
                      onChanged: _busy
                          ? null
                          : (value) => _run(() async {
                                _status = value!;
                                _page = 1;
                                _rows = [];
                                await _load();
                              })),
                  const SizedBox(height: 12),
                  if (_rows.isEmpty && !_busy && _error == null)
                    Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(_kind == 'dst' && _status == 1
                            ? 'Belum ada DST yang bisa diterima.'
                            : _kind == 'shipments' && _status == 1
                                ? 'Belum ada pesanan yang siap dikirim.'
                                : 'Tidak ada pengiriman untuk filter ini.')),
                  for (final row in _rows) _shipmentCard(row),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                            onPressed: _busy || _page <= 1
                                ? null
                                : () => _run(() async {
                                      _page--;
                                      await _load();
                                    }),
                            icon: const Icon(Icons.chevron_left)),
                        Text('Halaman $_page / $_totalPages'),
                        IconButton(
                            onPressed: _busy || _page >= _totalPages
                                ? null
                                : () => _run(() async {
                                      _page++;
                                      await _load();
                                    }),
                            icon: const Icon(Icons.chevron_right)),
                      ]),
                ],
              ]),
        )),
      ]),
    );
  }

  Widget _shipmentCard(Map<String, dynamic> row) {
    final dst = _kind == 'dst';
    final canReceive =
        row['recipient_button'] == true || row['recipient_button'] == 1;
    final orderStatus =
        row['status'].toString().toLowerCase().replaceAll(' ', '_');
    final canSend =
        const ['orders_ready', 'order_ready', '1'].contains(orderStatus) ||
            ((row['status'] == null || orderStatus.isEmpty) && _status == 1);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  dst
                      ? 'DST ${row['no_dst']}'
                      : 'Pesanan ${row['transaction_id']}',
                  style: Theme.of(context).textTheme.titleMedium),
              Text('${row['transaction_date'] ?? ''}'),
              Text('${row[dst ? 'recipient_hub' : 'send_to'] ?? ''}'),
              if (!dst)
                Text('${canSend ? 'Siap dikirim' : const [
                    'finish',
                    'finished',
                    '2'
                  ].contains(orderStatus) ? 'Sudah dikirim' : row['status'] ?? ''} · ${row['order_total'] ?? ''}'),
              if (dst) ...[
                Chip(
                  avatar: Icon(
                      canReceive
                          ? Icons.inventory_2_outlined
                          : Icons.info_outline,
                      size: 18),
                  label: Text(canReceive
                      ? 'Bisa diterima'
                      : _status == 2
                          ? 'Sudah diterima'
                          : 'Tidak bisa diterima'),
                ),
                if (row['status'] != null) Text('Status: ${row['status']}'),
                for (final dpp in row['list_dpp'] as List? ?? [])
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('DPP ${dpp['no_dpp']}'),
                      subtitle: Text('${dpp['customer_name'] ?? ''}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy
                          ? null
                          : () => _openDetail('dpp', '${dpp['no_dpp']}')),
                if (canReceive)
                  FilledButton.icon(
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Terima kiriman'),
                      onPressed: _busy
                          ? null
                          : () async {
                              if (await _confirm('Terima DST ${row['no_dst']}?',
                                      'Pastikan barang sudah diterima dan diperiksa.') &&
                                  mounted) {
                                await _run(() async {
                                  await widget.repository
                                      .receive('${row['no_dst']}');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('Kiriman diterima.')));
                                  }
                                  _kind = 'shipments';
                                  _status = 1;
                                  _page = 1;
                                  _search.clear();
                                  _rows = [];
                                  await _load();
                                });
                              }
                            }),
              ] else ...[
                OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _openDetail('order', '${row['transaction_id']}',
                            canSend: canSend),
                    child: const Text('Detail pesanan')),
                if (canSend)
                  FilledButton.icon(
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Kirim ke pembeli'),
                    onPressed: _busy
                        ? null
                        : () => _openDetail('order', '${row['transaction_id']}',
                            canSend: true),
                  ),
              ],
            ])));
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
          context: context,
          builder: (ctx) =>
              AlertDialog(title: Text(title), content: Text(message), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Batal')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Lanjutkan')),
              ])) ??
      false;

  Future<void> _openDetail(String kind, String id,
      {bool canSend = false}) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => _FggDetailPage(
            repository: widget.repository,
            kind: kind,
            id: id,
            canSend: canSend)));
    if (mounted) await _run(_load);
  }
}

class _FggDetailPage extends StatefulWidget {
  const _FggDetailPage(
      {required this.repository,
      required this.kind,
      required this.id,
      required this.canSend});
  final FggRepository repository;
  final String kind;
  final String id;
  final bool canSend;
  @override
  State<_FggDetailPage> createState() => _FggDetailPageState();
}

class _FggDetailPageState extends State<_FggDetailPage> {
  late Future<dynamic> _detail =
      widget.repository.detail(widget.kind, widget.id);
  XFile? _photo;
  bool _busy = false;
  bool _sent = false;
  bool _uncertain = false;
  bool _arrived = false;
  String? _error;

  Future<void> _capture() async {
    setState(() => _busy = true);
    try {
      final photo = await ImagePicker().pickImage(
          source: ImageSource.camera, maxWidth: 1600, imageQuality: 80);
      if (mounted && photo != null) setState(() => _photo = photo);
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = humanReadableError(e, action: 'mengambil foto'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Kirim pesanan ke pembeli?'),
                content: Text(
                    'Pesanan ${widget.id} akan diproses dengan foto bukti yang Anda ambil.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Batal')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Kirim'))
                ]));
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    bool submitted = false;
    try {
      final bytes = await _photo!.readAsBytes();
      if (bytes.length > 5000000) {
        throw StateError('Foto maksimal 5 MB. Ambil ulang foto.');
      }
      submitted = true;
      await widget.repository.send(widget.id, base64Encode(bytes));
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _uncertain = submitted &&
              e is! StateError &&
              !(e is ApiException && e.statusCode == 422);
          _error = _fggError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(
                '${widget.kind == 'dpp' ? 'DPP' : 'Pesanan'} ${widget.id}')),
        body: FutureBuilder<dynamic>(
            future: _detail,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(humanReadableError(snapshot.error!,
                              action: 'memuat detail')),
                          TextButton(
                              onPressed: () => setState(() => _detail = widget
                                  .repository
                                  .detail(widget.kind, widget.id)),
                              child: const Text('Coba lagi'))
                        ])));
              }
              final records = snapshot.data is List
                  ? snapshot.data as List
                  : [snapshot.data];
              return ListView(padding: const EdgeInsets.all(20), children: [
                if (widget.kind == 'order')
                  FggTripPanel(
                      repository: widget.repository,
                      orderId: widget.id,
                      canStart: widget.canSend && !_sent,
                      customerName:
                          '${records.whereType<Map>().firstOrNull?['customer_name'] ?? ''}',
                      phoneNumber:
                          '${records.whereType<Map>().firstOrNull?['phone_number'] ?? ''}',
                      destination: records
                              .whereType<Map>()
                              .map((r) => '${r['senders_address'] ?? ''}')
                              .where((s) => s.trim().isNotEmpty)
                              .firstOrNull ??
                          '',
                      onArrived: (value) {
                        if (mounted) setState(() => _arrived = value);
                      }),
                for (final record in records.whereType<Map>()) ...[
                  for (final field in const {
                    'customer_name': 'Pelanggan',
                    'transaction_date': 'Tanggal',
                    'senders_address': 'Alamat',
                    'phone_number': 'Telepon',
                    'payment_methode': 'Pembayaran',
                    'senders_methode': 'Pengiriman',
                    'delivery_hours': 'Jam',
                    'order_total': 'Total'
                  }.entries)
                    if (record[field.key] != null)
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(field.value),
                          subtitle: Text('${record[field.key]}')),
                  const Divider(),
                  for (final product in (record['product'] ??
                      record['listProduk'] ??
                      []) as List)
                    Card(
                        child: ListTile(
                            title: Text('${product['product_name'] ?? ''}'),
                            subtitle: Text(
                                '${product['qty'] ?? ''} × ${product['size'] ?? ''} · ${product['packaging_name'] ?? ''}\n${product['order_total'] ?? ''}'))),
                ],
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                if (_sent)
                  const ListTile(
                      leading: Icon(Icons.check_circle, color: Colors.green),
                      title: Text('Pesanan berhasil diproses.')),
                if (_uncertain)
                  const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                          'Periksa status pada daftar kiriman sebelum melakukan tindakan lanjutan.')),
                if (widget.canSend && !_sent && !_uncertain) ...[
                  const SizedBox(height: 20),
                  if (_photo != null)
                    Image.file(File(_photo!.path),
                        height: 220, fit: BoxFit.contain),
                  OutlinedButton.icon(
                      onPressed: _busy ? null : _capture,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(_photo == null
                          ? 'Ambil foto bukti'
                          : 'Ambil ulang foto')),
                  FilledButton(
                      onPressed:
                          _busy || _photo == null || !_arrived ? null : _send,
                      child: Text(_busy ? 'Memproses…' : 'Kirim ke pembeli')),
                  if (!_arrived)
                    const Text(
                        'Mulai perjalanan dan catat Tiba di tujuan sebelum mengirim bukti penyerahan.'),
                ],
              ]);
            }),
      );
}
