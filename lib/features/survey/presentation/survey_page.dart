import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_controller.dart';
import '../../../core/models/app_session.dart';
import '../../../core/models/survey_models.dart';
import '../../../core/models/territory_option.dart';
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
  final _phoneController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _otherProductController = TextEditingController();
  final _marketNameController = TextEditingController();
  final Map<String, TextEditingController> _lowestPriceControllers = {};
  final Map<String, TextEditingController> _highestPriceControllers = {};
  final _territory = _SurveyTerritoryState();

  XFile? _photo;
  bool _isLoadingTerritories = true;
  bool _isSubmitting = false;
  final Set<String> _selectedProductIds = {};
  final Set<String> _selectedBuildingTypes = {};
  final Set<String> _selectedKioskSizes = {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadProvinces());
  }

  @override
  void dispose() {
    _kioskNameController.dispose();
    _phoneController.dispose();
    _ownerNameController.dispose();
    _otherProductController.dispose();
    _marketNameController.dispose();
    _territory.dispose();
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
          _TerritorySection(
            state: _territory,
            isLoading: _isLoadingTerritories,
            onProvinceChanged: _onProvinceChanged,
            onCityChanged: _onCityChanged,
            onDistrictChanged: _onDistrictChanged,
            onSubdistrictChanged: (value) {
              setState(() {
                _territory.selectedSubdistrict = value;
                _territory.applySelectedTexts();
              });
            },
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
      _ChecklistCard(
        title: 'Bangunan',
        options: widget.options.buildingTypes,
        selectedLabels: _selectedBuildingTypes,
        onChanged: (label, selected) {
          setState(() {
            if (selected) {
              _selectedBuildingTypes.add(label);
            } else {
              _selectedBuildingTypes.remove(label);
            }
          });
        },
      ),
      const SizedBox(height: 16),
      _ChecklistCard(
        title: 'Luas Kios',
        options: widget.options.kioskSizes,
        selectedLabels: _selectedKioskSizes,
        onChanged: (label, selected) {
          setState(() {
            if (selected) {
              _selectedKioskSizes.add(label);
            } else {
              _selectedKioskSizes.remove(label);
            }
          });
        },
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

  Future<void> _loadProvinces() async {
    try {
      final provinces = await widget.controller.territoryProvinces();
      if (!mounted) {
        return;
      }
      setState(() {
        _territory.provinceOptions = provinces;
        _isLoadingTerritories = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingTerritories = false);
      }
    }
  }

  Future<void> _onProvinceChanged(TerritoryOption? province) async {
    setState(() {
      _isLoadingTerritories = true;
      _territory.selectProvince(province);
    });
    if (province == null) {
      setState(() => _isLoadingTerritories = false);
      return;
    }
    final cities = await widget.controller.territoryCities(province.code);
    if (!mounted) {
      return;
    }
    setState(() {
      _territory.cityOptions = cities;
      _isLoadingTerritories = false;
    });
  }

  Future<void> _onCityChanged(TerritoryOption? city) async {
    setState(() {
      _isLoadingTerritories = true;
      _territory.selectCity(city);
    });
    if (city == null) {
      setState(() => _isLoadingTerritories = false);
      return;
    }
    final districts = await widget.controller.territoryDistricts(city.code);
    if (!mounted) {
      return;
    }
    setState(() {
      _territory.districtOptions = districts;
      _isLoadingTerritories = false;
    });
  }

  Future<void> _onDistrictChanged(TerritoryOption? district) async {
    setState(() {
      _isLoadingTerritories = true;
      _territory.selectDistrict(district);
    });
    if (district == null) {
      setState(() => _isLoadingTerritories = false);
      return;
    }
    final subdistricts =
        await widget.controller.territorySubdistricts(district.code);
    if (!mounted) {
      return;
    }
    setState(() {
      _territory.subdistrictOptions = subdistricts;
      _isLoadingTerritories = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_photo == null) {
      _showMessage('Foto survey wajib diambil dari kamera HP.');
      return;
    }
    if (!_territory.isComplete) {
      _showMessage('Pilih wilayah sampai level kelurahan terlebih dahulu.');
      return;
    }
    if (widget.mode == _SurveyMode.kios) {
      if (_selectedProductIds.isEmpty &&
          _otherProductController.text.trim().isEmpty) {
        _showMessage('Pilih minimal satu produk atau isi produk lainnya.');
        return;
      }
      if (_selectedBuildingTypes.isEmpty || _selectedKioskSizes.isEmpty) {
        _showMessage('Checklist bangunan dan luas kios wajib diisi.');
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
      territoryProvince: _territory.provinceController.text.trim(),
      territoryCity: _territory.cityController.text.trim(),
      territoryDistrict: _territory.districtController.text.trim(),
      territorySubdistrict: _territory.subdistrictController.text.trim(),
      kioskName: _kioskNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      ownerName: _ownerNameController.text.trim(),
      productIds: _selectedProductIds.toList(),
      otherProduct: _otherProductController.text.trim(),
      buildingTypes: _selectedBuildingTypes.toList(),
      kioskSizes: _selectedKioskSizes.toList(),
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
      territoryProvince: _territory.provinceController.text.trim(),
      territoryCity: _territory.cityController.text.trim(),
      territoryDistrict: _territory.districtController.text.trim(),
      territorySubdistrict: _territory.subdistrictController.text.trim(),
      commodityPrices: prices,
    );
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

class _SurveyTerritoryState {
  final provinceController = TextEditingController();
  final cityController = TextEditingController();
  final districtController = TextEditingController();
  final subdistrictController = TextEditingController();

  List<TerritoryOption> provinceOptions = const [];
  List<TerritoryOption> cityOptions = const [];
  List<TerritoryOption> districtOptions = const [];
  List<TerritoryOption> subdistrictOptions = const [];
  TerritoryOption? selectedProvince;
  TerritoryOption? selectedCity;
  TerritoryOption? selectedDistrict;
  TerritoryOption? selectedSubdistrict;

  bool get isComplete {
    return provinceController.text.trim().isNotEmpty &&
        cityController.text.trim().isNotEmpty &&
        districtController.text.trim().isNotEmpty &&
        subdistrictController.text.trim().isNotEmpty;
  }

  void selectProvince(TerritoryOption? province) {
    selectedProvince = province;
    selectedCity = null;
    selectedDistrict = null;
    selectedSubdistrict = null;
    cityOptions = const [];
    districtOptions = const [];
    subdistrictOptions = const [];
    applySelectedTexts();
  }

  void selectCity(TerritoryOption? city) {
    selectedCity = city;
    selectedDistrict = null;
    selectedSubdistrict = null;
    districtOptions = const [];
    subdistrictOptions = const [];
    applySelectedTexts();
  }

  void selectDistrict(TerritoryOption? district) {
    selectedDistrict = district;
    selectedSubdistrict = null;
    subdistrictOptions = const [];
    applySelectedTexts();
  }

  void applySelectedTexts() {
    provinceController.text = selectedProvince?.name ?? '';
    cityController.text = selectedCity?.name ?? '';
    districtController.text = selectedDistrict?.name ?? '';
    subdistrictController.text = selectedSubdistrict?.name ?? '';
  }

  void dispose() {
    provinceController.dispose();
    cityController.dispose();
    districtController.dispose();
    subdistrictController.dispose();
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
                hint: 'Contoh: 12000',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TextInput(
                controller: highestController,
                label: 'Harga tertinggi',
                hint: 'Contoh: 15000',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TerritorySection extends StatelessWidget {
  const _TerritorySection({
    required this.state,
    required this.isLoading,
    required this.onProvinceChanged,
    required this.onCityChanged,
    required this.onDistrictChanged,
    required this.onSubdistrictChanged,
  });

  final _SurveyTerritoryState state;
  final bool isLoading;
  final ValueChanged<TerritoryOption?> onProvinceChanged;
  final ValueChanged<TerritoryOption?> onCityChanged;
  final ValueChanged<TerritoryOption?> onDistrictChanged;
  final ValueChanged<TerritoryOption?> onSubdistrictChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Wilayah Survey',
      children: [
        if (isLoading) const LinearProgressIndicator(minHeight: 3),
        _TerritoryDropdown(
          label: 'Provinsi',
          value: state.selectedProvince,
          items: state.provinceOptions,
          hint: 'Pilih provinsi',
          enabled: state.provinceOptions.isNotEmpty,
          onChanged: onProvinceChanged,
        ),
        _TerritoryDropdown(
          label: 'Kota/Kabupaten',
          value: state.selectedCity,
          items: state.cityOptions,
          hint: state.selectedProvince == null
              ? 'Pilih provinsi dulu'
              : 'Pilih kota/kabupaten',
          enabled: state.selectedProvince != null,
          onChanged: onCityChanged,
        ),
        _TerritoryDropdown(
          label: 'Kecamatan',
          value: state.selectedDistrict,
          items: state.districtOptions,
          hint: state.selectedCity == null
              ? 'Pilih kota/kabupaten dulu'
              : 'Pilih kecamatan',
          enabled: state.selectedCity != null,
          onChanged: onDistrictChanged,
        ),
        _TerritoryDropdown(
          label: 'Kelurahan',
          value: state.selectedSubdistrict,
          items: state.subdistrictOptions,
          hint: state.selectedDistrict == null
              ? 'Pilih kecamatan dulu'
              : 'Pilih kelurahan',
          enabled: state.selectedDistrict != null,
          onChanged: onSubdistrictChanged,
        ),
      ],
    );
  }
}

class _TerritoryDropdown extends StatelessWidget {
  const _TerritoryDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.hint,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final TerritoryOption? value;
  final List<TerritoryOption> items;
  final String hint;
  final bool enabled;
  final ValueChanged<TerritoryOption?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<TerritoryOption>(
      key: ValueKey('$label-${value?.code ?? 'empty'}-${items.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: '$label *', hintText: hint),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item.name),
              ))
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: (selected) => selected == null ? '$label wajib dipilih' : null,
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    required this.hint,
    this.required = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool required;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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
