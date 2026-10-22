import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/app_controller.dart';
import '../../../core/models/territory_option.dart';
import '../../../core/network/human_readable_error.dart';

class SupplierFormPage extends StatefulWidget {
  const SupplierFormPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<SupplierFormPage> createState() => _SupplierFormPageState();
}

class _SupplierFormPageState extends State<SupplierFormPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _phone = TextEditingController();
  final _picName = TextEditingController();
  final _address = TextEditingController(), _notes = TextEditingController();
  final _regions = List.generate(3, (_) => TextEditingController());
  final _selected = List<TerritoryOption?>.filled(3, null);
  final _items = [TextEditingController()];
  LatLng? _point;
  String _source = 'manual';
  bool _saving = false, _locating = false, _loadingRegion = false;
  String? _error, _locationMessage;
  bool get _busy => _saving || _locating || _loadingRegion;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _picName,
      _phone,
      _address,
      _notes,
      ..._regions,
      ..._items
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<List<TerritoryOption>> _options(int index) => switch (index) {
        0 => widget.controller.territoryProvinces(),
        1 => widget.controller.territoryCities(_selected[0]!.code),
        _ => widget.controller.territoryDistricts(_selected[1]!.code),
      };

  Future<void> _chooseRegion(int index) async {
    if (_busy) return;
    if (index > 0 && _selected[index - 1] == null) {
      _message('Pilih wilayah di atasnya terlebih dahulu.');
      return;
    }
    setState(() => _loadingRegion = true);
    try {
      final options = await _options(index);
      if (!mounted) return;
      if (options.isEmpty) {
        _message(
            'Daftar wilayah belum tersedia. Coba lagi setelah koneksi pulih.');
        return;
      }
      setState(() => _loadingRegion = false);
      final selected = await showModalBottomSheet<TerritoryOption>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _TerritoryPicker(
              options: options,
              title: ['Provinsi', 'Kota/Kabupaten', 'Kecamatan'][index]));
      if (!mounted || selected == null) return;
      setState(() {
        _selected[index] = selected;
        _regions[index].text = selected.name;
        for (var i = index + 1; i < 3; i++) {
          _selected[i] = null;
          _regions[i].clear();
        }
      });
    } catch (error) {
      _message(humanReadableError(error, action: 'memuat wilayah'));
    } finally {
      if (mounted) setState(() => _loadingRegion = false);
    }
  }

  Future<void> _gps() async {
    setState(() {
      _locating = true;
      _locationMessage = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _message('Aktifkan GPS, atau gunakan alamat manual / pilih peta.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _message(
            'Izin lokasi belum diberikan. Alamat manual atau titik peta tetap dapat digunakan.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 20)));
      await _applyPoint(LatLng(position.latitude, position.longitude), 'gps');
    } catch (error) {
      _message(humanReadableError(error, action: 'membaca GPS'));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickMap() async {
    final point = await Navigator.of(context).push<LatLng>(
        MaterialPageRoute(builder: (_) => _LocationPicker(initial: _point)));
    if (point == null || !mounted) return;
    setState(() => _locating = true);
    try {
      await _applyPoint(point, 'map');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _applyPoint(LatLng point, String source) async {
    if (!mounted) return;
    setState(() {
      _point = point;
      _source = source;
      _locationMessage =
          'Titik tersimpan. Wilayah dan alamat manual tidak perlu diisi.';
      _address.clear();
      for (var i = 0; i < 3; i++) {
        _regions[i].clear();
        _selected[i] = null;
      }
    });
    // Coordinates remain usable even when reverse geocoding is unavailable.
    try {
      final places =
          await placemarkFromCoordinates(point.latitude, point.longitude)
              .timeout(const Duration(seconds: 5));
      if (!mounted || places.isEmpty) return;
      final place = places.first;
      _address.text = [place.street, place.subLocality]
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .toSet()
          .join(', ');
      setState(() {
        _regions[0].text = place.administrativeArea ?? '';
        _regions[1].text = place.subAdministrativeArea ?? '';
        _regions[2].text = place.locality ?? '';
      });
    } catch (_) {
      // GPS coordinates are sufficient when address lookup is unavailable.
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final repository = widget.controller.supplierRepository;
    if (repository == null) {
      _message('Supplier membutuhkan koneksi backend staging.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await repository.create({
        'name': _name.text.trim(),
        'pic_name': _picName.text.trim(),
        'phone_number': _phone.text.trim(),
        'territory_province': _regions[0].text,
        'territory_city': _regions[1].text,
        'territory_district': _regions[2].text,
        'address': _address.text.trim(),
        'items': _items.map((c) => c.text.trim()).toList(),
        'notes': _notes.text.trim(),
        'location_source': _source,
        'latitude': _point?.latitude,
        'longitude': _point?.longitude,
      });
      if (!mounted) return;
      _message('Supplier berhasil disimpan.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() =>
            _error = humanReadableError(error, action: 'menyimpan supplier'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Wajib diisi.' : null;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: AppBar(title: const Text('Tambah Supplier')),
          body: Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                const Text('PIC pembuat otomatis menggunakan akun Anda.'),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _name,
                    enabled: !_saving,
                    maxLength: 255,
                    decoration:
                        const InputDecoration(labelText: 'Nama supplier'),
                    validator: _required),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _picName,
                    enabled: !_saving,
                    maxLength: 255,
                    decoration:
                        const InputDecoration(labelText: 'Nama PIC supplier'),
                    validator: _required),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _phone,
                    enabled: !_saving,
                    keyboardType: TextInputType.phone,
                    maxLength: 32,
                    decoration: const InputDecoration(labelText: 'No. HP'),
                    validator: (value) => RegExp(r'^\+?[0-9][0-9\s().-]{5,30}$')
                            .hasMatch(value?.trim() ?? '')
                        ? null
                        : 'Masukkan nomor HP yang valid.'),
                Card(
                    child: ExpansionTile(
                        title: const Text('Lokasi supplier'),
                        initiallyExpanded: false,
                        subtitle: Text(_point == null
                            ? 'Alamat manual / pilih lokasi'
                            : 'Titik lokasi sudah dipilih'),
                        childrenPadding: const EdgeInsets.all(12),
                        children: [
                      const Text(
                          'Gunakan GPS saat berada di supplier, atau tentukan titiknya di peta. Alamat manual boleh tanpa titik.'),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: [
                        OutlinedButton.icon(
                            onPressed: _busy ? null : _gps,
                            icon: const Icon(Icons.my_location),
                            label: const Text('Gunakan GPS')),
                        OutlinedButton.icon(
                            onPressed: _busy ? null : _pickMap,
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Pilih di peta')),
                      ]),
                      if (_locating) const LinearProgressIndicator(),
                      if (_point != null)
                        Text(
                            '${_point!.latitude.toStringAsFixed(6)}, ${_point!.longitude.toStringAsFixed(6)}'),
                      if (_locationMessage != null) Text(_locationMessage!),
                      if (_point != null)
                        TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                      _point = null;
                                      _source = 'manual';
                                      _locationMessage = null;
                                      _address.clear();
                                      for (var i = 0; i < 3; i++) {
                                        _regions[i].clear();
                                        _selected[i] = null;
                                      }
                                    }),
                            child: const Text(
                                'Hapus titik / gunakan alamat manual')),
                    ])),
                const SizedBox(height: 12),
                if (_source == 'manual') ...[
                  for (var i = 0; i < 3; i++)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _regions[i],
                          readOnly: true,
                          enabled: !_busy,
                          decoration: InputDecoration(
                              labelText: [
                                'Provinsi',
                                'Kota/Kabupaten',
                                'Kecamatan'
                              ][i],
                              suffixIcon: const Icon(Icons.arrow_drop_down)),
                          onTap: () => _chooseRegion(i),
                          validator: _required,
                        )),
                  if (_loadingRegion) const LinearProgressIndicator(),
                  TextFormField(
                      controller: _address,
                      enabled: !_saving,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration:
                          const InputDecoration(labelText: 'Alamat lengkap'),
                      validator: _required),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_address.text.isEmpty
                        ? 'Alamat menggunakan titik lokasi yang dipilih.'
                        : 'Alamat dari lokasi: ${_address.text}'),
                  ),
                const SizedBox(height: 16),
                Text('Jenis kebutuhan / Barang',
                    style: Theme.of(context).textTheme.titleMedium),
                const Text(
                    'Tambahkan satu atau beberapa barang yang disediakan supplier.'),
                const SizedBox(height: 12),
                for (var i = 0; i < _items.length; i++)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: TextFormField(
                            key: ValueKey(_items[i]),
                            controller: _items[i],
                            enabled: !_saving,
                            maxLength: 255,
                            decoration:
                                InputDecoration(labelText: 'Barang ${i + 1}'),
                            validator: (value) {
                              if (_required(value) != null) {
                                return 'Isi nama barang.';
                              }
                              final text = value!.trim().toLowerCase();
                              return _items
                                          .where((c) =>
                                              c.text.trim().toLowerCase() ==
                                              text)
                                          .length >
                                      1
                                  ? 'Barang sudah ada dalam daftar.'
                                  : null;
                            })),
                    IconButton(
                        tooltip: 'Hapus barang',
                        onPressed: _saving || _items.length == 1
                            ? null
                            : () {
                                final removed = _items[i];
                                setState(() => _items.removeAt(i));
                                WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => removed.dispose());
                              },
                        icon: const Icon(Icons.remove_circle_outline)),
                  ]),
                OutlinedButton.icon(
                    onPressed: _saving || _items.length >= 50
                        ? null
                        : () =>
                            setState(() => _items.add(TextEditingController())),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah barang')),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _notes,
                    enabled: !_saving,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 3000,
                    decoration: const InputDecoration(
                        labelText: 'Keterangan / Catatan (opsional)')),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_saving ? 'Menyimpan…' : 'Simpan Supplier')),
                const SizedBox(height: 24),
              ])),
        ),
      );
}

class _TerritoryPicker extends StatefulWidget {
  const _TerritoryPicker({required this.options, required this.title});
  final List<TerritoryOption> options;
  final String title;
  @override
  State<_TerritoryPicker> createState() => _TerritoryPickerState();
}

class _TerritoryPickerState extends State<_TerritoryPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final rows = widget.options
        .where((o) => o.name.toLowerCase().contains(_query))
        .toList();
    return SafeArea(
        child: Padding(
            padding: EdgeInsets.fromLTRB(
                16, 20, 16, MediaQuery.viewInsetsOf(context).bottom),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .65,
              child: Column(children: [
                Text('Pilih ${widget.title}',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                    decoration: const InputDecoration(
                        labelText: 'Cari wilayah',
                        prefixIcon: Icon(Icons.search)),
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase())),
                Expanded(
                    child: rows.isEmpty
                        ? const Center(child: Text('Wilayah tidak ditemukan.'))
                        : ListView.builder(
                            itemCount: rows.length,
                            itemBuilder: (context, i) => ListTile(
                                title: Text(rows[i].name),
                                onTap: () => Navigator.pop(context, rows[i])))),
              ]),
            )));
  }
}

class _LocationPicker extends StatefulWidget {
  const _LocationPicker({this.initial});
  final LatLng? initial;
  @override
  State<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<_LocationPicker> {
  LatLng? _point;
  @override
  void initState() {
    super.initState();
    _point = widget.initial;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pilih lokasi supplier')),
        body: Column(children: [
          const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Perbesar peta lalu ketuk lokasi supplier.')),
          Expanded(
              child: FlutterMap(
                  options: MapOptions(
                      initialCenter: _point ?? const LatLng(-2.5, 118),
                      initialZoom: _point == null ? 5 : 16,
                      onTap: (_, point) => setState(() => _point = point)),
                  children: [
                TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'com.folony.activity.folony_activity'),
                if (_point != null)
                  MarkerLayer(markers: [
                    Marker(
                        point: _point!,
                        width: 44,
                        height: 44,
                        child: const Icon(Icons.location_on,
                            size: 44, color: Colors.red))
                  ]),
                RichAttributionWidget(attributions: [
                  TextSourceAttribution('OpenStreetMap contributors')
                ]),
              ])),
          SafeArea(
              top: false,
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton(
                      onPressed: _point == null
                          ? null
                          : () => Navigator.pop(context, _point),
                      child: const Text('Gunakan titik ini')))),
        ]),
      );
}
