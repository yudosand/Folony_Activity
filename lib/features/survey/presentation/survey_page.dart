import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_controller.dart';
import '../../../core/models/app_session.dart';
import '../../../core/models/survey_models.dart';
import '../../../core/network/human_readable_error.dart';

enum _SurveyMode { kios, harga }

class SurveyPage extends StatefulWidget {
  const SurveyPage({
    super.key,
    required this.session,
    required this.controller,
  });

  final AppSession session;
  final AppController controller;

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  _SurveyMode? _mode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadOptions());
    });
  }

  Future<void> _loadOptions() async {
    try {
      await widget.controller.refreshSurveyOptions();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Master survey belum berhasil dimuat: ${humanReadableError(error, action: 'memuat master survey')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final options = widget.controller.surveyOptions;
        return RefreshIndicator(
          onRefresh: _loadOptions,
          child: _mode == null
              ? _SurveyChoiceView(onSelected: (mode) {
                  setState(() => _mode = mode);
                })
              : _SurveyFormView(
                  mode: _mode!,
                  session: widget.session,
                  controller: widget.controller,
                  options: options,
                  onBack: () => setState(() => _mode = null),
                ),
        );
      },
    );
  }
}

class _SurveyChoiceView extends StatelessWidget {
  const _SurveyChoiceView({
    required this.onSelected,
  });

  final ValueChanged<_SurveyMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Pilih Jenis Survey',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Data survey akan masuk ke Web Admin HR untuk rekap dan audit.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 20),
        _SurveyChoiceCard(
          icon: Icons.storefront_rounded,
          title: 'Survey Kios',
          subtitle: 'Foto kios, data pemilik, produk, bangunan, dan luas kios.',
          onTap: () => onSelected(_SurveyMode.kios),
        ),
        const SizedBox(height: 16),
        _SurveyChoiceCard(
          icon: Icons.price_change_rounded,
          title: 'Survey Harga',
          subtitle:
              'Foto pasar, lokasi, dan harga komoditas yang ditentukan HR.',
          onTap: () => onSelected(_SurveyMode.harga),
        ),
      ],
    );
  }
}

class _SurveyFormView extends StatefulWidget {
  const _SurveyFormView({
    required this.mode,
    required this.session,
    required this.controller,
    required this.options,
    required this.onBack,
  });

  final _SurveyMode mode;
  final AppSession session;
  final AppController controller;
  final SurveyOptions options;
  final VoidCallback onBack;

  @override
  State<_SurveyFormView> createState() => _SurveyFormViewState();
}

class _SurveyFormViewState extends State<_SurveyFormView> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _kioskNameController = TextEditingController();
  final _kioskAddressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _otherProductController = TextEditingController();
  final _marketNameController = TextEditingController();
  final Map<String, TextEditingController> _lowestPriceControllers = {};
  final Map<String, TextEditingController> _highestPriceControllers = {};

  XFile? _photo;
  Position? _surveyPosition;
  String? _surveyAddress;
  String? _locationError;
  bool _isCapturingLocation = true;
  bool _isSubmitting = false;
  final Set<String> _selectedProductIds = {};
  String? _selectedBuildingType;
  String? _selectedKioskSize;

  @override
  void initState() {
    super.initState();
    unawaited(_captureSurveyLocation());
  }

  @override
  void dispose() {
    _kioskNameController.dispose();
    _kioskAddressController.dispose();
    _phoneController.dispose();
    _ownerNameController.dispose();
    _otherProductController.dispose();
    _marketNameController.dispose();
    for (final controller in _lowestPriceControllers.values) {
      controller.dispose();
    }
    for (final controller in _highestPriceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _ensurePriceControllers();
    final isKios = widget.mode == _SurveyMode.kios;
    final title = isKios ? 'Survey Kios' : 'Survey Harga';

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PhotoCard(
            photo: _photo,
            onPick: _pickPhoto,
            onRemove: () => setState(() => _photo = null),
          ),
          const SizedBox(height: 16),
          _GpsSurveyLocationCard(
            position: _surveyPosition,
            address: _surveyAddress,
            isLoading: _isCapturingLocation,
            errorText: _locationError,
            onRefresh: _captureSurveyLocation,
          ),
          const SizedBox(height: 16),
          if (isKios) ..._buildKioskFields() else ..._buildPriceFields(),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(_isSubmitting ? 'Menyimpan...' : 'Simpan $title'),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  List<Widget> _buildKioskFields() {
    return [
      _SectionCard(
        title: 'Data Kios',
        children: [
          _TextInput(
            controller: _kioskNameController,
            label: 'Nama kios',
            hint: 'Contoh: Kios Makmur',
            required: true,
          ),
          _TextInput(
            controller: _kioskAddressController,
            label: 'Alamat kios',
            hint: 'Contoh: Jl. Pasar Baru No. 12',
            required: true,
            maxLines: 2,
          ),
          _TextInput(
            controller: _phoneController,
            label: 'Nomor HP',
            hint: '08xxxxxxxxxx',
            keyboardType: TextInputType.phone,
            required: true,
          ),
          _TextInput(
            controller: _ownerNameController,
            label: 'Nama pemilik',
            hint: 'Nama pemilik kios',
            required: true,
          ),
        ],
      ),
      const SizedBox(height: 16),
      _ChecklistCard(
        title: 'Checklist Produk',
        options: widget.options.products.map((item) => item.name).toList(),
        selectedLabels: widget.options.products
            .where((item) => _selectedProductIds.contains(item.id))
            .map((item) => item.name)
            .toSet(),
        onChanged: (label, selected) {
          final option = widget.options.products.firstWhere(
            (item) => item.name == label,
            orElse: () => SurveyChoiceOption(id: label, name: label),
          );
          setState(() {
            if (selected) {
              _selectedProductIds.add(option.id);
            } else {
              _selectedProductIds.remove(option.id);
            }
          });
        },
        trailing: _TextInput(
          controller: _otherProductController,
          label: 'Produk lainnya',
          hint: 'Tulis produk lain jika ada',
        ),
      ),
      const SizedBox(height: 16),
      _RadioChoiceCard(
        title: 'Bangunan',
        options: widget.options.buildingTypes,
        selectedLabel: _selectedBuildingType,
        onChanged: (label) => setState(() => _selectedBuildingType = label),
      ),
      const SizedBox(height: 16),
      _RadioChoiceCard(
        title: 'Luas Kios',
        options: widget.options.kioskSizes,
        selectedLabel: _selectedKioskSize,
        onChanged: (label) => setState(() => _selectedKioskSize = label),
      ),
    ];
  }

  List<Widget> _buildPriceFields() {
    return [
      _SectionCard(
        title: 'Data Pasar',
        children: [
          _TextInput(
            controller: _marketNameController,
            label: 'Nama pasar',
            hint: 'Contoh: Pasar Minggu',
            required: true,
          ),
        ],
      ),
      const SizedBox(height: 16),
      _SectionCard(
        title: 'Harga Komoditas',
        children: widget.options.commodities.map((commodity) {
          final suffix = commodity.unit == null || commodity.unit!.isEmpty
              ? null
              : 'per ${commodity.unit}';
          return _CommodityPriceInput(
            commodityName: commodity.name,
            unitLabel: suffix,
            lowestController: _lowestPriceControllers[commodity.id]!,
            highestController: _highestPriceControllers[commodity.id]!,
          );
        }).toList(),
      ),
    ];
  }

  void _ensurePriceControllers() {
    for (final commodity in widget.options.commodities) {
      _lowestPriceControllers.putIfAbsent(
        commodity.id,
        () => TextEditingController(),
      );
      _highestPriceControllers.putIfAbsent(
        commodity.id,
        () => TextEditingController(),
      );
    }
  }

  Future<void> _pickPhoto() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 52,
      maxWidth: 960,
      maxHeight: 960,
    );
    if (photo == null) {
      return;
    }
    setState(() => _photo = photo);
  }

  Future<void> _captureSurveyLocation() async {
      setState(() {
        _isCapturingLocation = true;
        _locationError = null;
        _surveyAddress = null;
      });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }
        setState(() {
          _surveyPosition = null;
          _surveyAddress = null;
          _locationError =
              'GPS belum aktif. Aktifkan lokasi device terlebih dahulu.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }
        setState(() {
          _surveyPosition = null;
          _surveyAddress = null;
          _locationError =
              'Izin lokasi dibutuhkan untuk menyimpan titik survey.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final address = await _resolveAddress(position);

      if (!mounted) {
        return;
      }
      setState(() {
        _surveyPosition = position;
        _surveyAddress = address;
        _locationError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _surveyPosition = null;
          _locationError =
              'Lokasi belum berhasil dibaca. Pastikan GPS stabil lalu coba lagi.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturingLocation = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_photo == null) {
      _showMessage('Foto survey wajib diambil dari kamera HP.');
      return;
    }
    if (_surveyPosition == null) {
      _showMessage('Ambil lokasi GPS survey terlebih dahulu.');
      return;
    }
    if (widget.mode == _SurveyMode.kios) {
      if (_selectedProductIds.isEmpty &&
          _otherProductController.text.trim().isEmpty) {
        _showMessage('Pilih minimal satu produk atau isi produk lainnya.');
        return;
      }
      if (_selectedBuildingType == null || _selectedKioskSize == null) {
        _showMessage('Pilih bangunan dan luas kios terlebih dahulu.');
        return;
      }
    } else if (_collectPriceSubmissions() == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (widget.mode == _SurveyMode.kios) {
        await _submitKios();
      } else {
        await _submitHarga();
      }
      if (!mounted) {
        return;
      }
      _showMessage('Survey berhasil disimpan ke Web Admin HR.');
      widget.onBack();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(
        'Simpan survey gagal: ${humanReadableError(error, action: 'menyimpan survey')}',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitKios() async {
    await widget.controller.submitKioskSurvey(
      session: widget.session,
      photoPath: _photo!.path,
      latitude: _surveyPosition!.latitude,
      longitude: _surveyPosition!.longitude,
      locationAccuracyMeters: _surveyPosition!.accuracy,
      locationAddress: _surveyAddress ?? '',
      kioskName: _kioskNameController.text.trim(),
      kioskAddress: _kioskAddressController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      ownerName: _ownerNameController.text.trim(),
      productIds: _selectedProductIds.toList(),
      otherProduct: _otherProductController.text.trim(),
      buildingTypes: [_selectedBuildingType!],
      kioskSizes: [_selectedKioskSize!],
    );
  }

  Future<void> _submitHarga() async {
    final prices = _collectPriceSubmissions();
    if (prices == null) {
      return;
    }

    await widget.controller.submitPriceSurvey(
      session: widget.session,
      photoPath: _photo!.path,
      marketName: _marketNameController.text.trim(),
      latitude: _surveyPosition!.latitude,
      longitude: _surveyPosition!.longitude,
      locationAccuracyMeters: _surveyPosition!.accuracy,
      locationAddress: _surveyAddress ?? '',
      commodityPrices: prices,
    );
  }

  Future<String?> _resolveAddress(Position position) async {
    try {
      final places = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 5));
      if (places.isEmpty) {
        return null;
      }
      final place = places.first;
      final parts = [
        place.street,
        place.subLocality,
        place.locality,
        place.subAdministrativeArea,
        place.administrativeArea,
        place.postalCode,
      ].whereType<String>().map((item) => item.trim()).where((item) {
        return item.isNotEmpty;
      }).toSet();
      return parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  List<CommodityPriceSubmission>? _collectPriceSubmissions() {
    final prices = <CommodityPriceSubmission>[];
    for (final commodity in widget.options.commodities) {
      final rawLowest =
          _lowestPriceControllers[commodity.id]?.text.trim() ?? '';
      final rawHighest =
          _highestPriceControllers[commodity.id]?.text.trim() ?? '';
      if (rawLowest.isEmpty && rawHighest.isEmpty) {
        continue;
      }
      if (rawLowest.isEmpty || rawHighest.isEmpty) {
        _showMessage(
          'Harga terendah dan tertinggi ${commodity.name} wajib diisi lengkap.',
        );
        return null;
      }
      final lowestPrice = _parsePrice(rawLowest);
      final highestPrice = _parsePrice(rawHighest);
      if (lowestPrice == null || highestPrice == null) {
        _showMessage('Harga ${commodity.name} belum valid.');
        return null;
      }
      if (lowestPrice > highestPrice) {
        _showMessage(
          'Harga terendah ${commodity.name} tidak boleh lebih besar dari harga tertinggi.',
        );
        return null;
      }
      prices.add(CommodityPriceSubmission(
        commodityId: commodity.id,
        commodityName: commodity.name,
        unit: commodity.unit,
        lowestPrice: lowestPrice,
        highestPrice: highestPrice,
      ));
    }
    if (prices.isEmpty) {
      _showMessage('Isi minimal satu harga komoditas.');
      return null;
    }
    return prices;
  }

  double? _parsePrice(String raw) {
    final normalized = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _SurveyChoiceCard extends StatelessWidget {
  const _SurveyChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                child: Icon(icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.photo,
    required this.onPick,
    required this.onRemove,
  });

  final XFile? photo;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: photo == null
                  ? Container(
                      width: 84,
                      height: 84,
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.camera_alt_rounded),
                    )
                  : Image.file(
                      File(photo!.path),
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload Foto',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text('Ambil foto langsung dari kamera HP.'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: onPick,
                        icon: const Icon(Icons.photo_camera_rounded),
                        label: Text(photo == null ? 'Ambil Foto' : 'Ulangi'),
                      ),
                      if (photo != null)
                        TextButton(
                          onPressed: onRemove,
                          child: const Text('Hapus'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children.expand((child) => [child, const SizedBox(height: 12)]),
          ],
        ),
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({
    required this.title,
    required this.options,
    required this.selectedLabels,
    required this.onChanged,
    this.trailing,
  });

  final String title;
  final List<String> options;
  final Set<String> selectedLabels;
  final void Function(String label, bool selected) onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      children: [
        ...options.map((option) {
          return CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(option),
            value: selectedLabels.contains(option),
            onChanged: (value) => onChanged(option, value ?? false),
          );
        }),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _RadioChoiceCard extends StatelessWidget {
  const _RadioChoiceCard({
    required this.title,
    required this.options,
    required this.selectedLabel,
    required this.onChanged,
  });

  final String title;
  final List<String> options;
  final String? selectedLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      children: options.map((option) {
        final selected = selectedLabel == option;
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onChanged(option),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(option)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CommodityPriceInput extends StatelessWidget {
  const _CommodityPriceInput({
    required this.commodityName,
    required this.lowestController,
    required this.highestController,
    this.unitLabel,
  });

  final String commodityName;
  final String? unitLabel;
  final TextEditingController lowestController;
  final TextEditingController highestController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          commodityName,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (unitLabel != null) ...[
          const SizedBox(height: 2),
          Text(
            unitLabel!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TextInput(
                controller: lowestController,
                label: 'Harga terendah',
                hint: 'Contoh: Rp 12.000',
                keyboardType: TextInputType.number,
                inputFormatters: const [_RupiahInputFormatter()],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TextInput(
                controller: highestController,
                label: 'Harga tertinggi',
                hint: 'Contoh: Rp 15.000',
                keyboardType: TextInputType.number,
                inputFormatters: const [_RupiahInputFormatter()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GpsSurveyLocationCard extends StatelessWidget {
  const _GpsSurveyLocationCard({
    required this.position,
    required this.address,
    required this.isLoading,
    required this.errorText,
    required this.onRefresh,
  });

  final Position? position;
  final String? address;
  final bool isLoading;
  final String? errorText;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPosition = position != null;
    final coordinateText = hasPosition
        ? '${position!.latitude.toStringAsFixed(6)}, ${position!.longitude.toStringAsFixed(6)}'
        : 'Belum ada lokasi';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: hasPosition
                      ? const Color(0xFFE4F6EA)
                      : const Color(0xFFFFF1D6),
                  foregroundColor: hasPosition
                      ? const Color(0xFF18803A)
                      : const Color(0xFFB45309),
                  child: Icon(
                    hasPosition
                        ? Icons.my_location_rounded
                        : Icons.location_searching_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wilayah Survey dari GPS',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Aplikasi otomatis menyimpan titik lokasi survey. User tidak perlu pilih provinsi/kota manual.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: isLoading ? null : onRefresh,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Koordinat', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(coordinateText, style: theme.textTheme.titleMedium),
                  if (hasPosition) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Akurasi sekitar ${position!.accuracy.toStringAsFixed(0)} meter',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (address != null && address!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Alamat terbaca',
                          style: theme.textTheme.labelMedium),
                      const SizedBox(height: 4),
                      Text(
                        address!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ],
              ),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    required this.hint,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
      ),
      validator: required
          ? (value) {
              if ((value ?? '').trim().isEmpty) {
                return '$label wajib diisi';
              }
              return null;
            }
          : null,
    );
  }
}

class _RupiahInputFormatter extends TextInputFormatter {
  const _RupiahInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = 'Rp ${_formatThousands(digits)}';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _formatThousands(String digits) {
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index += 1) {
      final reverseIndex = digits.length - index;
      buffer.write(digits[index]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }
}
