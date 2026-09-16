import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/repositories/fgg_repository.dart';
import '../../../core/network/human_readable_error.dart';
import '../../../core/services/fgg_directions_address.dart';

class FggTripPanel extends StatefulWidget {
  const FggTripPanel(
      {super.key,
      required this.repository,
      required this.orderId,
      required this.canStart,
      required this.destination,
      required this.onArrived,
      this.customerName = '',
      this.phoneNumber = '',
      this.launchDirections});
  final FggRepository repository;
  final String orderId;
  final bool canStart;
  final String destination;
  final String customerName;
  final String phoneNumber;
  final ValueChanged<bool> onArrived;
  final Future<bool> Function(Uri)? launchDirections;

  @override
  State<FggTripPanel> createState() => _FggTripPanelState();
}

class _FggTripPanelState extends State<FggTripPanel> {
  Map<String, dynamic>? _trip;
  bool _busy = true;
  String? _error;
  Timer? _timer;
  late final TextEditingController _mapsAddress;
  bool _addressEdited = false;

  String _clean(String value) => fggDirectionsAddress(value,
      customerName: widget.customerName, phoneNumber: widget.phoneNumber);

  @override
  void initState() {
    super.initState();
    _mapsAddress = TextEditingController(text: _clean(widget.destination));
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _trip != null && _trip!['arrived_at'] == null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapsAddress.dispose();
    super.dispose();
  }

  Future<void> _load({String? action}) async {
    if (action == 'start' && _mapsAddress.text.trim().isEmpty) {
      setState(() =>
          _error = 'Isi alamat tujuan untuk Google Maps terlebih dahulu.');
      return;
    }
    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      final trip = await widget.repository.trip(widget.orderId, action: action);
      if (!mounted) return;
      setState(() => _trip = trip);
      if (!_addressEdited && trip?['destination_address'] != null) {
        _mapsAddress.text = _clean('${trip!['destination_address']}');
      }
      widget.onArrived(trip?['arrived_at'] != null);
      if (action == 'start') await _directions();
    } catch (error) {
      if (mounted) {
        setState(() =>
            _error = humanReadableError(error, action: 'mencatat perjalanan'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _directions() async {
    final destination = _mapsAddress.text.trim();
    if (destination.isEmpty) {
      setState(() =>
          _error = 'Isi alamat tujuan untuk Google Maps terlebih dahulu.');
      return;
    }
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
      'travelmode': 'driving',
      'dir_action': 'navigate',
    });
    try {
      if (!await (widget.launchDirections?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication))) {
        throw StateError('Peta tidak dapat dibuka.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Perjalanan tetap tercatat. Tekan Buka direction untuk mencoba membuka peta lagi.');
      }
    }
  }

  Future<void> _arrive() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Sudah tiba di tujuan?'),
              content: const Text(
                  'Waktu perjalanan akan dihentikan dan lokasi GPS saat ini dicatat.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Sudah tiba'))
              ],
            ));
    if (confirmed == true && mounted) await _load(action: 'arrive');
  }

  String _elapsed() {
    final started = DateTime.tryParse('${_trip?['started_at']}');
    final duration = _trip?['duration_seconds'];
    final seconds = duration is num
        ? duration.toInt()
        : started == null
            ? 0
            : DateTime.now().difference(started).inSeconds.clamp(0, 2147483647);
    return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final arrived = _trip?['arrived_at'] != null;
    final completed = _trip?['completed_at'] != null;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Perjalanan pengiriman',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _mapsAddress,
                  enabled: !_busy,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Alamat untuk Google Maps',
                    helperText:
                        'Hanya alamat. Bisa dikoreksi sebelum membuka peta.',
                  ),
                  onChanged: (_) => _addressEdited = true,
                ),
                const Text(
                    'Periksa tujuan di peta sebelum berangkat. Waktu dihitung dari Mulai perjalanan sampai Tiba di tujuan.'),
                if (_busy) const LinearProgressIndicator(),
                if (_trip != null) ...[
                  const SizedBox(height: 12),
                  Text(
                      completed && !arrived
                          ? 'Waktu tiba belum tercatat'
                          : '${arrived ? 'Durasi perjalanan' : 'Perjalanan berlangsung'}: ${_elapsed()}',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                      'Mulai: ${DateTime.tryParse('${_trip!['started_at']}')?.toLocal() ?? '-'}'),
                  if (arrived)
                    Text(
                        'Tiba: ${DateTime.tryParse('${_trip!['arrived_at']}')?.toLocal() ?? '-'}'),
                  OutlinedButton.icon(
                      onPressed: _busy ? null : _directions,
                      icon: const Icon(Icons.directions),
                      label: const Text('Buka direction')),
                  if (!arrived && !completed)
                    FilledButton(
                        onPressed: _busy ? null : _arrive,
                        child: const Text('Tiba di tujuan')),
                ] else if (!_busy && _error == null && widget.canStart)
                  FilledButton.icon(
                      onPressed: widget.destination.trim().isEmpty
                          ? null
                          : () => _load(action: 'start'),
                      icon: const Icon(Icons.navigation),
                      label: const Text('Mulai perjalanan & direction')),
                if (!_busy && _trip == null && !widget.canStart)
                  const Text('Perjalanan belum tercatat untuk pesanan ini.'),
                if (_error != null) ...[
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  TextButton(
                      onPressed: _busy ? null : () => _load(),
                      child: const Text('Muat ulang perjalanan'))
                ],
              ],
            )));
  }
}
