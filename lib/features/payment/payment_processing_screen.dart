import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spendrail_worker_app/l10n/app_localizations.dart';
import 'package:spendrail_worker_app/models/transaction_model.dart';
import 'package:spendrail_worker_app/services/payment_service.dart';
import 'package:spendrail_worker_app/theme.dart';

class PaymentProcessingScreen extends ConsumerStatefulWidget {
  final String firebaseId;

  const PaymentProcessingScreen({super.key, required this.firebaseId});

  @override
  ConsumerState<PaymentProcessingScreen> createState() => _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends ConsumerState<PaymentProcessingScreen> {
  StreamSubscription? _subscription;
  bool _isProcessing = true;
  TransactionModel? _transaction;

  @override
  void initState() {
    super.initState();
    _listenToTransaction();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _listenToTransaction() {
    final paymentService = ref.read(paymentServiceProvider);
    _subscription = paymentService.listenToTransaction(widget.firebaseId).listen(
      (transaction) {
        setState(() {
          _transaction = transaction;
          if (transaction.status == TransactionStatus.completed || 
              transaction.status == TransactionStatus.disapproved) {
            _isProcessing = false;
          }
        });
      },
      onError: (error) {
        debugPrint('Transaction listener error: $error');
        setState(() {
          _isProcessing = false;
          _transaction = TransactionModel(
            id: widget.firebaseId,
            userId: '',
            amount: 0,
            qrData: '',
            status: TransactionStatus.timeout,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_isProcessing) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                ),
                SizedBox(height: AppSpacing.xl),
                Text(l10n.translate('processing'), style: context.textStyles.titleLarge?.semiBold),
                SizedBox(height: AppSpacing.md),
                Text('Please wait while we process your payment', style: context.textStyles.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    final isSuccess = _transaction?.status == TransactionStatus.completed;
    final statusColor = isSuccess ? const Color(0xFF388E3C) : const Color(0xFFD32F2F);
    final statusIcon = isSuccess ? Icons.check_circle : Icons.cancel;
    final statusTitle = isSuccess ? l10n.translate('payment_success') : _getFailureTitle(l10n);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(statusIcon, size: 100, color: statusColor),
              SizedBox(height: AppSpacing.xl),
              Text(statusTitle, style: context.textStyles.headlineMedium?.bold?.copyWith(color: statusColor), textAlign: TextAlign.center),
              if (_transaction != null) ...[
                SizedBox(height: AppSpacing.xl),
                Card(
                  child: Padding(
                    padding: AppSpacing.paddingLg,
                    child: Column(
                      children: [
                        _buildInfoRow('Amount', '₹${_transaction!.amount.toStringAsFixed(2)}', context),
                        Divider(height: AppSpacing.lg),
                        _buildInfoRow('Category', _transaction!.category.name.toUpperCase(), context),
                        Divider(height: AppSpacing.lg),
                        _buildInfoRow('Status', _transaction!.status.name.toUpperCase(), context),
                      ],
                    ),
                  ),
                ),
              ],
              SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: Text('Back to Home'),
              ),
              SizedBox(height: AppSpacing.md),
              if (!isSuccess)
                OutlinedButton(
                  onPressed: () => context.go('/scan-qr'),
                  child: Text(l10n.translate('try_again')),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFailureTitle(AppLocalizations l10n) {
    if (_transaction?.status == TransactionStatus.disapproved) {
      return l10n.translate('payment_disapproved');
    } else if (_transaction?.status == TransactionStatus.timeout) {
      return l10n.translate('payment_timeout');
    }
    return l10n.translate('payment_failed');
  }

  Widget _buildInfoRow(String label, String value, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: context.textStyles.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(value, style: context.textStyles.bodyMedium?.semiBold),
      ],
    );
  }
}
