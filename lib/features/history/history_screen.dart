import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:spendrail_worker_app/l10n/app_localizations.dart';
import 'package:spendrail_worker_app/models/transaction_model.dart';
import 'package:spendrail_worker_app/services/analytics_service.dart';
import 'package:spendrail_worker_app/services/auth_service.dart';
import 'package:spendrail_worker_app/services/payment_service.dart';
import 'package:spendrail_worker_app/theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

final allTransactionsProvider =
    FutureProvider<List<TransactionModel>>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final paymentService = ref.watch(paymentServiceProvider);
  final userId = authService.currentUser?.uid;

  if (userId == null) return [];

  return await paymentService.getUserTransactions(userId);
});

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  TransactionCategory? _selectedCategory;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final transactionsAsync = ref.watch(allTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('history')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => _exportReport(transactionsAsync.value ?? []),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: l10n.translate('search'),
                      prefixIcon:
                          Icon(Icons.search, color: theme.colorScheme.primary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  SizedBox(height: AppSpacing.md),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: Text('All'),
                          selected: _selectedCategory == null,
                          onSelected: (selected) =>
                              setState(() => _selectedCategory = null),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        ...TransactionCategory.values.map((category) => Padding(
                              padding: EdgeInsets.only(right: AppSpacing.sm),
                              child: FilterChip(
                                label: Text(category.name.toUpperCase()),
                                selected: _selectedCategory == category,
                                onSelected: (selected) => setState(() =>
                                    _selectedCategory =
                                        selected ? category : null),
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: transactionsAsync.when(
                data: (transactions) {
                  final filteredTransactions =
                      _filterTransactions(transactions);

                  if (filteredTransactions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant),
                          SizedBox(height: AppSpacing.md),
                          Text('No transactions found',
                              style: context.textStyles.titleMedium?.semiBold),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: AppSpacing.paddingLg,
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) => TransactionCard(
                        transaction: filteredTransactions[index],
                        onUploadInvoice: (t) => _handleUploadInvoice(t)),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: ${e.toString()}')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUploadInvoice(TransactionModel t) async {
    try {
      final authService = ref.read(authServiceProvider);
      final paymentService = ref.read(paymentServiceProvider);
      final userId = authService.currentUser?.uid;
      if (userId == null) return;

      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (image == null) return;

      // Show simple progress dialog while uploading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }

      try {
        final bytes = await image.readAsBytes();
        await paymentService.uploadInvoiceAndCategorize(
          firebaseId: t.id,
          userId: userId,
          data: bytes,
          filename: image.name,
        );
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Invoice uploaded')));
        }
        // Refresh list
        ref.invalidate(allTransactionsProvider);
      } catch (e) {
        debugPrint('History invoice upload failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ));
        }
      } finally {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      debugPrint('handleUploadInvoice error: $e');
    }
  }

  List<TransactionModel> _filterTransactions(
      List<TransactionModel> transactions) {
    return transactions.where((t) {
      final matchesSearch = _searchQuery.isEmpty ||
          t.qrData.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (t.note?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      final matchesCategory =
          _selectedCategory == null || t.category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  void _exportReport(List<TransactionModel> transactions) {
    final analyticsService = AnalyticsService();
    final csv = analyticsService.exportToCSV(transactions);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('Report exported (${transactions.length} transactions)')),
    );

    debugPrint('CSV Export:\n$csv');
  }
}

class TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final void Function(TransactionModel transaction)? onUploadInvoice;

  const TransactionCard({super.key, required this.transaction, this.onUploadInvoice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');

    Color getStatusColor() {
      switch (transaction.status) {
        case TransactionStatus.payment_completed:
          return const Color(0xFF388E3C);
        case TransactionStatus.waiting_on_approval:
        case TransactionStatus.waiting_on_manual_approval:
          return const Color(0xFFFFB300);
        case TransactionStatus.transaction_approved:
          return const Color(0xFF1976D2);
        case TransactionStatus.payment_declined:
        case TransactionStatus.transaction_disapproved:
        case TransactionStatus.payment_in_progress:
          return Theme.of(context).colorScheme.primary;
        case TransactionStatus.timeout:
          return const Color(0xFFD32F2F);
      }
    }

    IconData getCategoryIcon() {
      switch (transaction.category) {
        case TransactionCategory.food:
          return Icons.restaurant;
        case TransactionCategory.travel:
          return Icons.directions_car;
        case TransactionCategory.supplies:
          return Icons.shopping_bag;
        case TransactionCategory.other:
          return Icons.more_horiz;
      }
    }

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(getCategoryIcon(), color: theme.colorScheme.primary),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(transaction.category.name.toUpperCase(),
                          style: context.textStyles.bodyLarge?.semiBold),
                      SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant),
                          SizedBox(width: AppSpacing.xs),
                          Text(
                              '${dateFormat.format(transaction.createdAt)} at ${timeFormat.format(transaction.createdAt)}',
                              style: context.textStyles.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
                Text('₹${transaction.amount.toStringAsFixed(2)}',
                    style: context.textStyles.titleMedium?.bold
                        ?.copyWith(color: theme.colorScheme.primary)),
              ],
            ),
            if (transaction.note != null) ...[
              SizedBox(height: AppSpacing.md),
              Text(transaction.note!,
                  style: context.textStyles.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: getStatusColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(transaction.status.name.toUpperCase(),
                  style: context.textStyles.labelSmall?.copyWith(
                      color: getStatusColor(), fontWeight: FontWeight.bold)),
            ),
            if (transaction.amount > 200 && (transaction.invoiceUrl == null || transaction.invoiceUrl!.isEmpty)) ...[
              SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: onUploadInvoice == null ? null : () => onUploadInvoice!(transaction),
                icon: Icon(Icons.upload_rounded, color: Theme.of(context).colorScheme.primary),
                label: const Text('Upload invoice'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
