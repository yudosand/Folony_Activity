import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/app_controller.dart';
import '../../../core/models/app_session.dart';
import '../../../core/models/heat_map_snapshot.dart';
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
  int _radiusMeter = 1000;
  bool _isLoading = true;
  String? _errorMessage;
  HeatMapSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = _snapshot;
    final points = snapshot?.points ?? const <HeatMapPoint>[];

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
                : '${points.length} titik dalam radius ${_radiusLabel(_radiusMeter)} dari posisi user aktif.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _MapPreview(
            markerCount: points.length,
            isLoading: _isLoading,
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
            'Detail memuat pemilik data, alamat, nomor HP, jarak, dan catatan lapangan terbaru.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
          else if (points.isEmpty)
            const EmptyState(
              icon: Icons.location_searching_rounded,
              title: 'Tidak ada titik',
              message:
                  'Belum ada data yang masuk dalam radius aktif. Coba perluas radius atau refresh lokasi.',
            )
          else
            for (var i = 0; i < points.length; i++) ...[
              _MapPointRow(
                point: points[i],
                onOpen: () => _showPointDetail(points[i]),
              ),
              if (i != points.length - 1) const Divider(height: 24),
            ],
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final coordinate = await _resolveCoordinate();
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
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage =
            'Tidak bisa mengambil lokasi sekarang. Menampilkan data sesuai koordinat fallback area.';
      });
      final fallback = _fallbackCoordinate();
      final snapshot = await widget.controller.loadHeatMap(
        latitude: fallback.latitude,
        longitude: fallback.longitude,
        radiusMeters: _radiusMeter,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
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
        accuracy: LocationAccuracy.medium,
      ),
    );
    return _Coordinate(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  _Coordinate _fallbackCoordinate() {
    return switch (widget.session.role.name) {
      'areaManager' || 'fgg' => const _Coordinate(
          latitude: -6.3690,
          longitude: 106.8315,
        ),
      _ => const _Coordinate(
          latitude: -6.2000,
          longitude: 106.8166,
        ),
    };
  }

  void _showPointDetail(HeatMapPoint point) {
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                    StatusBadge(
                      label: _statusLabel(point.status),
                      color: _statusColor(point.status),
                    ),
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
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Direction mock ke ${point.name}'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('Direction'),
                ),
              ],
            ),
          ),
        );
      },
    );
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

class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.markerCount,
    required this.isLoading,
  });

  final int markerCount;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 178,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MapGridPainter(
                lineColor: theme.dividerColor,
                pointColor: theme.colorScheme.primary,
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 16,
            child: StatusBadge(
              label: isLoading ? 'Sync lokasi' : 'GPS Aktif',
              color: isLoading ? Colors.orange : Colors.green,
            ),
          ),
          Positioned(
            left: 20,
            bottom: 16,
            child: Text(
              '$markerCount marker aktif',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter({
    required this.lineColor,
    required this.pointColor,
  });

  final Color lineColor;
  final Color pointColor;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    final markerPaint = Paint()..color = pointColor;
    final userPaint = Paint()..color = Colors.orange;

    for (var i = 1; i < 4; i++) {
      final dx = size.width * i / 4;
      final dy = size.height * i / 4;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), linePaint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), linePaint);
    }

    canvas.drawCircle(Offset(size.width * .5, size.height * .55), 8, userPaint);
    canvas.drawCircle(
      Offset(size.width * .35, size.height * .34),
      6,
      markerPaint,
    );
    canvas.drawCircle(
      Offset(size.width * .67, size.height * .42),
      6,
      markerPaint,
    );
    canvas.drawCircle(
      Offset(size.width * .58, size.height * .73),
      6,
      markerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.pointColor != pointColor;
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
