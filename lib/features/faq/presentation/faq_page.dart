import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/models/faq_item.dart';
import '../../../core/network/human_readable_error.dart';

class FaqPage extends StatefulWidget {
  const FaqPage({
    super.key,
    required this.controller,
  });

  final AppController controller;

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final items = widget.controller.faqItems;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Pusat Bantuan',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Pilih panduan yang kamu butuhkan. HR bisa memperbarui daftar ini dari web admin.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 18),
              if (_isRefreshing) const LinearProgressIndicator(),
              if (_isRefreshing) const SizedBox(height: 16),
              if (items.isEmpty)
                const _FaqEmptyCard()
              else
                for (final item in items) ...[
                  _FaqListCard(
                    item: item,
                    onTap: () => _openDetail(item),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      await widget.controller.refreshFaqs();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Muat FAQ gagal: ${humanReadableError(error, action: 'memuat FAQ')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _openDetail(FaqItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(item.title)),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE7E5E4)),
                ),
                child: Text(
                  item.body,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqListCard extends StatelessWidget {
  const _FaqListCard({
    required this.item,
    required this.onTap,
  });

  final FaqItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE7E5E4)),
        ),
        child: Row(
          children: [
            Icon(Icons.help_outline_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(item.title, style: theme.textTheme.titleMedium),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _FaqEmptyCard extends StatelessWidget {
  const _FaqEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: const Text('Belum ada FAQ dari HR.'),
    );
  }
}
