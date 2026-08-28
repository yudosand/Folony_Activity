import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_controller.dart';
import '../../../core/models/app_session.dart';
import '../../../core/models/heat_map_snapshot.dart';
import '../../../core/network/human_readable_error.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';

class HeatMapPage extends StatefulWidget {
  const HeatMapPage({
    super.key,
    required this.session,
    required this.controller,
  });

  final AppSession session;
  final AppController controller;

  @override
  State<HeatMapPage> createState() => _HeatMapPageState();
}

class _HeatMapPageState extends State<HeatMapPage> {
  final _searchController = TextEditingController();
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _lastLiveRefreshAt;
  int _radiusMeter = 1000;
  bool _isLoading = true;
  String? _errorMessage;
  HeatMapSnapshot? _snapshot;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
    _refresh();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = _snapshot;
    final points = snapshot?.points ?? const <HeatMapPoint>[];
    final visiblePoints = _filterPoints(points);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Peta Persebaran',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              StatusBadge(
                label: widget.controller.isRemoteAuthEnabled
                    ? 'Live Radius'
                    : 'Mock Radius',
                color: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            snapshot == null
                ? 'Ambil lokasi user aktif lalu tampilkan titik yang masuk dalam radius.'
                : '${visiblePoints.length} dari ${points.length} titik dalam radius ${_radiusLabel(_radiusMeter)} dari posisi user aktif.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _MapPreview(
            snapshot: snapshot,
            points: visiblePoints,
            isLoading: _isLoading,
            onPointTap: _showPointDetail,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text('Radius', style: theme.textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: _isLoading ? null : _refresh,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Refresh lokasi'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 500, label: Text('500 m')),
              ButtonSegment(value: 1000, label: Text('1 km')),
              ButtonSegment(value: 2000, label: Text('2 km')),
            ],
            selected: {_radiusMeter},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              setState(() => _radiusMeter = selection.first);
              _refresh();
            },
          ),
          const SizedBox(height: 22),
          Text('Titik Terdekat', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Cari titik, buka direction, atau mulai kunjungan dengan timer dan foto dokumentasi.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
              labelText: 'Cari titik heatmap',
              hintText: 'Nama UKM, owner, alamat, nomor HP',
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null && snapshot == null)
            Column(
              children: [
                EmptyState(
                  icon: Icons.location_off_rounded,
                  title: 'Lokasi belum siap',
                  message: _errorMessage!,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _refresh,
                  child: const Text('Coba Lagi'),
                ),
              ],
            )
          else if (visiblePoints.isEmpty)
            EmptyState(
              icon: Icons.location_searching_rounded,
              title:
                  _searchQuery.isEmpty ? 'Tidak ada titik' : 'Tidak ditemukan',
              message: _searchQuery.isEmpty
                  ? 'Belum ada data yang masuk dalam radius aktif. Coba perluas radius atau refresh lokasi.'
                  : 'Tidak ada titik yang cocok dengan pencarian "$_searchQuery".',
            )
          else
            for (var i = 0; i < visiblePoints.length; i++) ...[
              _MapPointRow(
                point: visiblePoints[i],
                onOpen: () => _showPointDetail(visiblePoints[i]),
              ),
              if (i != visiblePoints.length - 1) const Divider(height: 24),
            ],
        ],
      ),
    );
  }

  List<HeatMapPoint> _filterPoints(List<HeatMapPoint> points) {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) {
      return points;
    }

    return points.where((point) {
      final haystack = [
        point.name,
        point.ownerName,
        point.address,
        point.phoneNumber,
        point.type,
        point.status,
        point.note ?? '',
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final coordinate = await _resolveCoordinate();
      await _loadSnapshotForCoordinate(coordinate);
      _startLocationWatch();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = null;
        _errorMessage = _locationErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<_Coordinate> _resolveCoordinate() async {
    final isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      throw StateError('GPS belum aktif.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Izin lokasi belum diberikan.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return _Coordinate(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<void> _loadSnapshotForCoordinate(_Coordinate coordinate) async {
    final snapshot = await widget.controller.loadHeatMap(
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
      radiusMeters: _radiusMeter,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _snapshot = snapshot;
      _errorMessage = null;
    });
  }

  void _startLocationWatch() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    ).listen((position) async {
      final now = DateTime.now();
      if (_lastLiveRefreshAt != null &&
          now.difference(_lastLiveRefreshAt!) < const Duration(seconds: 12)) {
        return;
      }
      _lastLiveRefreshAt = now;
      try {
        await _loadSnapshotForCoordinate(
          _Coordinate(
            latitude: position.latitude,
            longitude: position.longitude,
          ),
        );
      } catch (_) {
        // Manual refresh tetap tersedia jika jaringan/GPS sesaat gagal.
      }
    });
  }

  String _locationErrorMessage(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('gps') || raw.contains('service')) {
      return 'GPS belum aktif. Aktifkan lokasi perangkat lalu tekan Refresh lokasi.';
    }
    if (raw.contains('permission') || raw.contains('izin')) {
      return 'Izin lokasi belum diberikan. Berikan izin lokasi agar Heat Map membaca posisi Anda sekarang.';
    }
    if (raw.contains('timeout')) {
      return 'Lokasi belum terbaca dalam 12 detik. Pastikan GPS aktif dan sinyal lokasi stabil, lalu coba lagi.';
    }

    return 'Lokasi belum berhasil dibaca. Heat Map hanya akan tampil setelah GPS live berhasil didapat.';
  }

  void _showPointDetail(HeatMapPoint point) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _HeatMapPointDetailPage(
          point: point,
          statusLabel: _statusLabel(point.status),
          statusColor: _statusColor(point.status),
          onDirection: () => _openDirection(point),
          onVisit: () => _showVisitSheet(point),
        ),
      ),
    );
  }

  Future<void> _showVisitSheet(HeatMapPoint point) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) {
          return _VisitPage(
            controller: widget.controller,
            session: widget.session,
            point: point,
          );
        },
      ),
    );

    if (!mounted || saved != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Kunjungan ${point.name} berhasil disimpan.')),
    );
    try {
      await _refresh();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kunjungan tersimpan. Data terbaru akan muncul setelah refresh ulang.',
          ),
        ),
      );
    }
  }

  Future<void> _openDirection(HeatMapPoint point) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${point.latitude},${point.longitude}',
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Tidak bisa membuka Google Maps untuk ${point.name}.')),
      );
    }
  }

  String _radiusLabel(int radiusMeter) {
    return radiusMeter >= 1000 ? '${radiusMeter ~/ 1000} km' : '$radiusMeter m';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'followUp':
        return 'Follow-up';
      case 'completed':
        return 'Lengkap';
      case 'archived':
        return 'Arsip';
      case 'draft':
      default:
        return 'Draft';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'followUp':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'archived':
        return Colors.blueGrey;
      case 'draft':
      default:
        return Colors.teal;
    }
  }
}

class _HeatMapPointDetailPage extends StatelessWidget {
  const _HeatMapPointDetailPage({
    required this.point,
    required this.statusLabel,
    required this.statusColor,
    required this.onDirection,
    required this.onVisit,
  });

  final HeatMapPoint point;
  final String statusLabel;
  final Color statusColor;
  final Future<void> Function() onDirection;
  final Future<void> Function() onVisit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Titik'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(point.name, style: theme.textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text(
                              '${point.type.toUpperCase()} - ${point.distanceLabel}',
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(label: statusLabel, color: statusColor),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _DetailLine(label: 'Pemilik', value: point.ownerName),
                  const Divider(height: 24),
                  _DetailLine(label: 'Alamat', value: point.address),
                  const Divider(height: 24),
                  _DetailLine(label: 'Nomor HP', value: point.phoneNumber),
                  const Divider(height: 24),
                  _DetailLine(
                    label: 'Catatan',
                    value: point.note ?? 'Belum ada catatan lapangan.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDirection,
                    icon: const Icon(Icons.directions_rounded),
                    label: const Text('Direction'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onVisit,
                    icon: const Icon(Icons.timer_rounded),
                    label: const Text('Kunjungi'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitPage extends StatefulWidget {
  const _VisitPage({
    required this.controller,
    required this.session,
    required this.point,
  });

  final AppController controller;
  final AppSession session;
  final HeatMapPoint point;

  @override
  State<_VisitPage> createState() => _VisitPageState();
}

class _VisitPageState extends State<_VisitPage> {
  final _visitTypeController = TextEditingController();
  final _imagePicker = ImagePicker();
  late final DateTime _startedAt;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  XFile? _photo;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsed = DateTime.now().difference(_startedAt));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _visitTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kunjungan Heatmap'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kunjungi ${widget.point.name}',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Timer berjalan sejak form ini dibuka.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: _formatElapsed(_elapsed),
                    color: Colors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _visitTypeController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Type kunjungan',
                  hintText: 'Contoh: Follow up, survey harga, cek stok',
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(
                      _photo == null
                          ? Icons.camera_alt_outlined
                          : Icons.check_circle_rounded,
                      color: _photo == null ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _photo == null
                            ? 'Foto dokumentasi dari kamera wajib diisi.'
                            : 'Foto siap dikirim: ${_photo!.name}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: _isSaving ? null : _pickPhoto,
                      child: Text(_photo == null ? 'Ambil Foto' : 'Ulangi'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? 'Menyimpan' : 'Simpan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 72,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() => _photo = picked);
  }

  Future<void> _save() async {
    final visitType = _visitTypeController.text.trim();
    if (visitType.isEmpty || _photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lengkapi type kunjungan dan foto dokumentasi.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.controller.recordHeatMapVisit(
        session: widget.session,
        point: widget.point,
        visitType: visitType,
        photoPath: _photo!.path,
        startedAt: _startedAt,
        finishedAt: DateTime.now(),
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kunjungan belum tersimpan: ${humanReadableError(error, action: 'menyimpan kunjungan')}',
          ),
        ),
      );
    }
  }

  String _formatElapsed(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class _MapPreview extends StatefulWidget {
  const _MapPreview({
    required this.snapshot,
    required this.points,
    required this.isLoading,
    required this.onPointTap,
  });

  final HeatMapSnapshot? snapshot;
  final List<HeatMapPoint> points;
  final bool isLoading;
  final ValueChanged<HeatMapPoint> onPointTap;

  @override
  State<_MapPreview> createState() => _MapPreviewState();
}

class _MapPreviewState extends State<_MapPreview> {
  final MapController _mapController = MapController();
  double _zoom = 15;
  bool _isMapReady = false;

  @override
  void didUpdateWidget(covariant _MapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.snapshot?.userLocation;
    final current = widget.snapshot?.userLocation;
    if (_isMapReady &&
        current != null &&
        (previous == null ||
            previous.latitude != current.latitude ||
            previous.longitude != current.longitude)) {
      _focusUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final center = widget.snapshot?.userLocation;
    final userPoint = center == null
        ? const LatLng(-6.2000, 106.8166)
        : LatLng(center.latitude, center.longitude);
    final radiusMeters = widget.snapshot?.radiusMeters ?? 0;

    return Container(
      height: 360,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF14201E),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: userPoint,
                initialZoom: _zoom,
                minZoom: 4,
                maxZoom: 19,
                keepAlive: true,
                backgroundColor: const Color(0xFF14201E),
                onMapReady: () {
                  _isMapReady = true;
                  _focusUser();
                },
                onPositionChanged: (camera, hasGesture) {
                  if (!mounted || !hasGesture) {
                    return;
                  }
                  setState(() => _zoom = camera.zoom);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'id.folony.activity',
                  maxZoom: 19,
                  errorTileCallback: (_, __, ___) {},
                ),
                if (center != null && radiusMeters > 0)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: userPoint,
                        radius: radiusMeters.toDouble(),
                        useRadiusInMeter: true,
                        color: Colors.teal.withValues(alpha: 0.22),
                        borderColor: Colors.tealAccent.shade400,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (final point in widget.points)
                      Marker(
                        point: LatLng(point.latitude, point.longitude),
                        width: 46,
                        height: 52,
                        alignment: Alignment.topCenter,
                        child: _MapPin(
                          point: point,
                          onTap: () => widget.onPointTap(point),
                        ),
                      ),
                    if (center != null)
                      Marker(
                        point: userPoint,
                        width: 54,
                        height: 54,
                        child: const _UserPin(),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.14),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.18),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 16,
            child: StatusBadge(
              label: widget.isLoading ? 'Sync lokasi' : 'Satellite Live',
              color: widget.isLoading ? Colors.orange : Colors.green,
            ),
          ),
          Positioned(
            right: 14,
            top: 14,
            child: _MapControlColumn(
              onZoomIn: () => _moveZoom(1),
              onZoomOut: () => _moveZoom(-1),
              onFocusUser: _focusUser,
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MapLegendPill(
                  color: Colors.teal,
                  label: 'UKM',
                  value: widget.points
                      .where((point) => point.type != 'mitra')
                      .length
                      .toString(),
                ),
                _MapLegendPill(
                  color: Colors.orange,
                  label: 'Mitra',
                  value: widget.points
                      .where((point) => point.type == 'mitra')
                      .length
                      .toString(),
                ),
                _MapLegendPill(
                  color: Colors.blue,
                  label: 'Zoom',
                  value: _zoom.toStringAsFixed(1),
                ),
              ],
            ),
          ),
          if (center == null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.34),
                child: Center(
                  child: Text(
                    'Menunggu lokasi untuk membuka peta.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _focusUser() {
    final center = widget.snapshot?.userLocation;
    if (!_isMapReady || center == null) {
      return;
    }
    final nextZoom = _zoom < 14 ? 15.0 : _zoom;
    _mapController.move(LatLng(center.latitude, center.longitude), nextZoom);
    if (mounted) {
      setState(() => _zoom = nextZoom);
    }
  }

  void _moveZoom(double delta) {
    final center = widget.snapshot?.userLocation;
    if (!_isMapReady || center == null) {
      return;
    }
    final nextZoom = (_zoom + delta).clamp(4.0, 19.0).toDouble();
    _mapController.move(LatLng(center.latitude, center.longitude), nextZoom);
    setState(() => _zoom = nextZoom);
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.point,
    required this.onTap,
  });

  final HeatMapPoint point;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: point.name,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: point.type == 'mitra' ? Colors.orange : Colors.teal,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                point.type == 'mitra'
                    ? Icons.storefront_rounded
                    : Icons.location_on_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            Container(
              width: 3,
              height: 8,
              decoration: BoxDecoration(
                color: point.type == 'mitra' ? Colors.orange : Colors.teal,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserPin extends StatelessWidget {
  const _UserPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white),
    );
  }
}

class _MapControlColumn extends StatelessWidget {
  const _MapControlColumn({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFocusUser,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFocusUser;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapIconButton(icon: Icons.add_rounded, onPressed: onZoomIn),
          const Divider(height: 1),
          _MapIconButton(icon: Icons.remove_rounded, onPressed: onZoomOut),
          const Divider(height: 1),
          _MapIconButton(
            icon: Icons.my_location_rounded,
            onPressed: onFocusUser,
          ),
        ],
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      color: const Color(0xFF0F766E),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class _MapLegendPill extends StatelessWidget {
  const _MapLegendPill({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label $value',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF10231F),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPointRow extends StatelessWidget {
  const _MapPointRow({
    required this.point,
    required this.onOpen,
  });

  final HeatMapPoint point;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.location_on_rounded, size: 18, color: Colors.orange),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(point.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                '${point.type.toUpperCase()} - ${point.distanceLabel} - ${point.note ?? 'Belum ada catatan'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: onOpen,
          child: const Text('Buka'),
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _Coordinate {
  const _Coordinate({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

extension on HeatMapPoint {
  String get distanceLabel {
    if (distanceMeter >= 1000) {
      return '${(distanceMeter / 1000).toStringAsFixed(1)} km';
    }
    return '$distanceMeter m';
  }
}
