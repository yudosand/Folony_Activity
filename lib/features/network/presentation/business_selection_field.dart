import 'package:flutter/material.dart';
import '../../../core/repositories/business_catalog_repository.dart';

class BusinessSelectionField extends StatefulWidget {
  const BusinessSelectionField(
      {super.key,
      required this.repository,
      required this.onChanged,
      this.categoryId,
      this.kindId,
      this.originalText});
  final BusinessCatalogRepository? repository;
  final String? categoryId;
  final String? kindId;
  final String? originalText;
  final void Function(String? categoryId, String? kindId, String name)
      onChanged;
  @override
  State<BusinessSelectionField> createState() => _BusinessSelectionFieldState();
}

class _BusinessSelectionFieldState extends State<BusinessSelectionField> {
  List<BusinessCategoryOption> _categories = [];
  String? _categoryId;
  String? _kindId;
  String _search = '';
  bool _loading = true;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final repo = widget.repository;
      if (repo == null) throw StateError('Master belum tersedia');
      final categories = await repo.load();
      if (!mounted) return;
      final matches = categories.where((c) => c.id == widget.categoryId);
      final category = matches.isEmpty ? null : matches.first;
      final kinds =
          category?.kinds.where((k) => k.id == widget.kindId).toList() ?? [];
      setState(() {
        _categories = categories;
        _categoryId = category?.id;
        _kindId = kinds.isEmpty ? null : kinds.first.id;
        _loading = false;
      });
      widget.onChanged(
          _categoryId, _kindId, kinds.isEmpty ? '' : kinds.first.name);
    } catch (_) {
      if (mounted)
        setState(() {
          _failed = true;
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _categories.where((c) => c.id == _categoryId);
    final kinds =
        selected.isEmpty ? <BusinessKindOption>[] : selected.first.kinds;
    final filtered = kinds
        .where((k) =>
            k.id == _kindId ||
            k.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_loading) const LinearProgressIndicator(),
      if (_failed)
        Row(children: [
          const Expanded(child: Text('Master jenis usaha belum dapat dimuat.')),
          TextButton(onPressed: _load, child: const Text('Coba lagi'))
        ]),
      if ((widget.originalText ?? '').isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Isian sebelumnya: ${widget.originalText}')),
      DropdownButtonFormField<String>(
        key: ValueKey('category-$_categoryId-${_categories.length}'),
        initialValue: _categoryId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Kategori Usaha'),
        items: _categories
            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
            .toList(),
        validator: (v) => v == null ? 'Pilih kategori usaha' : null,
        onChanged: _loading || _failed
            ? null
            : (v) {
                setState(() {
                  _categoryId = v;
                  _kindId = null;
                  _search = '';
                });
                widget.onChanged(v, null, '');
              },
      ),
      const SizedBox(height: 12),
      if (kinds.length > 12) ...[
        TextField(
            key: ValueKey('search-$_categoryId'),
            decoration: const InputDecoration(
                labelText: 'Cari jenis usaha', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _search = v)),
        const SizedBox(height: 12),
      ],
      DropdownButtonFormField<String>(
        key: ValueKey('kind-$_categoryId-$_kindId-${filtered.length}'),
        initialValue: _kindId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Jenis Usaha'),
        items: filtered
            .map((k) => DropdownMenuItem(
                value: k.id,
                child: Text(k.name, overflow: TextOverflow.ellipsis)))
            .toList(),
        validator: (v) => v == null ? 'Pilih jenis usaha' : null,
        onChanged: _categoryId == null || _loading || _failed
            ? null
            : (v) {
                setState(() => _kindId = v);
                widget.onChanged(
                    _categoryId, v, kinds.firstWhere((k) => k.id == v).name);
              },
      ),
    ]);
  }
}
