import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:spendrail_worker_app/l10n/app_localizations.dart';
import 'package:spendrail_worker_app/models/transaction_model.dart';
import 'package:spendrail_worker_app/services/auth_service.dart';
import 'package:spendrail_worker_app/services/payment_service.dart';
import 'package:spendrail_worker_app/theme.dart';

final recentTransactionsProvider =
    FutureProvider<List<TransactionModel>>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final paymentService = ref.watch(paymentServiceProvider);
  final userId = authService.currentUser?.uid;

  if (userId == null) return [];

  return await paymentService.getUserTransactions(userId, limit: 5);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final userData = ref.watch(currentUserDataProvider);
    final recentTransactions = ref.watch(recentTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('my_wallet')),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: AppSpacing.paddingLg,
                child: Text(l10n.translate('menu'),
                    style: context.textStyles.titleLarge?.semiBold),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.person, color: theme.colorScheme.primary),
                title: Text(l10n.translate('profile'),
                    style: context.textStyles.bodyLarge),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/profile');
                },
              ),
              ListTile(
                leading: Icon(Icons.history_rounded,
                    color: theme.colorScheme.primary),
                title: Text(l10n.translate('history'),
                    style: context.textStyles.bodyLarge),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/history');
                },
              ),
              ListTile(
                leading: Icon(Icons.analytics_rounded,
                    color: theme.colorScheme.primary),
                title: Text(l10n.translate('analytics'),
                    style: context.textStyles.bodyLarge),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/analytics');
                },
              ),
              const Spacer(),
              Padding(
                padding: AppSpacing.paddingLg,
                child: Consumer(
                  builder: (context, ref, _) {
                    return ElevatedButton.icon(
                      onPressed: () async {
                        final authService = ref.read(authServiceProvider);
                        await authService.signOut();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout),
                      label: Text(l10n.translate('logout')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              userData.when(
                data: (user) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.translate('welcome_back'),
                        style: context.textStyles.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    SizedBox(height: AppSpacing.xs),
                    Text(user?.name ?? 'User',
                        style: context.textStyles.headlineMedium?.bold),
                  ],
                ),
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => const SizedBox.shrink(),
              ),
              SizedBox(height: AppSpacing.xl),
              Text(l10n.translate('quick_actions'),
                  style: context.textStyles.titleLarge?.semiBold),
              SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                      child: QuickActionCard(
                    icon: Icons.qr_code_scanner_rounded,
                    label: l10n.translate('pay_now'),
                    color: theme.colorScheme.primary,
                    onTap: () => context.push('/scan-qr'),
                  )),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                      child: QuickActionCard(
                    icon: Icons.approval_rounded,
                    label: l10n.translate('request_approval'),
                    color: theme.colorScheme.secondary,
                    onTap: () => context.push('/request-approval'),
                  )),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                      child: QuickActionCard(
                    icon: Icons.history_rounded,
                    label: l10n.translate('history'),
                    color: theme.colorScheme.tertiary,
                    onTap: () => context.push('/history'),
                  )),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                      child: QuickActionCard(
                    icon: Icons.analytics_rounded,
                    label: l10n.translate('analytics'),
                    color: const Color(0xFF9C27B0),
                    onTap: () => context.push('/analytics'),
                  )),
                ],
              ),
              SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.translate('recent_transactions'),
                      style: context.textStyles.titleLarge?.semiBold),
                  TextButton(
                    onPressed: () => context.push('/history'),
                    child: Text(l10n.translate('view_all')),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              recentTransactions.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.translate('no_transactions'),
                      subtitle: l10n.translate('start_scanning'),
                    );
                  }
                  return Column(
                    children: transactions
                        .map((t) => TransactionListItem(transaction: t))
                        .toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => EmptyStateWidget(
                  icon: Icons.error_outline,
                  title: l10n.translate('error_occurred'),
                  subtitle: e.toString(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              SizedBox(height: AppSpacing.md),
              Text(label,
                  style: context.textStyles.bodyMedium?.semiBold,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class TransactionListItem extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionListItem({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    IconData getStatusIcon() {
      switch (transaction.status) {
        case TransactionStatus.payment_completed:
          return Icons.check_circle;
        case TransactionStatus.waiting_on_approval:
        case TransactionStatus.waiting_on_manual_approval:
          return Icons.hourglass_empty;
        case TransactionStatus.transaction_approved:
          return Icons.thumb_up;
        case TransactionStatus.payment_declined:
        case TransactionStatus.transaction_disapproved:
          return Icons.cancel;
        case TransactionStatus.payment_in_progress:
          return Icons.payments;
        case TransactionStatus.timeout:
          return Icons.error;
      }
    }

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
          return const Color(0xFFD32F2F);
        case TransactionStatus.payment_in_progress:
          return Theme.of(context).colorScheme.primary;
        case TransactionStatus.timeout:
          return const Color(0xFFD32F2F);
      }
    }

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: getStatusColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(getStatusIcon(), color: getStatusColor()),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(transaction.category.name.toUpperCase(),
                      style: context.textStyles.bodyMedium?.semiBold),
                  SizedBox(height: AppSpacing.xs),
                  Text(dateFormat.format(transaction.createdAt),
                      style: context.textStyles.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Text('₹${transaction.amount.toStringAsFixed(2)}',
                style: context.textStyles.titleMedium?.bold
                    ?.copyWith(color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.onSurfaceVariant),
            SizedBox(height: AppSpacing.md),
            Text(title,
                style: context.textStyles.titleMedium?.semiBold,
                textAlign: TextAlign.center),
            SizedBox(height: AppSpacing.sm),
            Text(subtitle,
                style: context.textStyles.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
