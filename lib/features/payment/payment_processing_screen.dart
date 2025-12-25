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
  Timer? _manualApprovalTimer;
  Duration _manualRemaining = const Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _listenToTransaction();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _manualApprovalTimer?.cancel();
    super.dispose();
  }

  void _listenToTransaction() {
    final paymentService = ref.read(paymentServiceProvider);
    _subscription = paymentService.listenToTransaction(widget.firebaseId).listen(
      (transaction) {
        setState(() {
          _transaction = transaction;
          _handleCountdown(transaction.status);
          if (transaction.status == TransactionStatus.payment_completed ||
              transaction.status == TransactionStatus.payment_declined ||
              transaction.status == TransactionStatus.transaction_disapproved ||
              transaction.status == TransactionStatus.timeout) {
            _isProcessing = false;
          } else {
            _isProcessing = true;
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

  void _handleCountdown(TransactionStatus status) {
    if (status == TransactionStatus.waiting_on_manual_approval) {
      // Start countdown if not started
      _manualApprovalTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          final secondsLeft = _manualRemaining.inSeconds - 1;
          _manualRemaining = Duration(seconds: secondsLeft.clamp(0, 300));
          if (_manualRemaining.inSeconds <= 0) {
            t.cancel();
          }
        });
      });
    } else {
      // Stop countdown when leaving manual approval
      _manualApprovalTimer?.cancel();
      _manualApprovalTimer = null;
      _manualRemaining = const Duration(minutes: 5);
    }
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
                _buildProcessingVisual(theme),
                SizedBox(height: AppSpacing.xl),
                Text(_processingTitle(l10n), style: context.textStyles.titleLarge?.semiBold),
                SizedBox(height: AppSpacing.md),
                if (_transaction?.status == TransactionStatus.waiting_on_manual_approval)
                  _buildCountdownChip(theme)
                else
                  Text('Please wait while we process your payment', style: context.textStyles.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    final isSuccess = _transaction?.status == TransactionStatus.payment_completed;
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
    if (_transaction?.status == TransactionStatus.transaction_disapproved ||
        _transaction?.status == TransactionStatus.payment_declined) {
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

  Widget _buildProcessingVisual(ThemeData theme) {
    final status = _transaction?.status;
    if (status == TransactionStatus.payment_in_progress) {
      return SizedBox(
        width: 100,
        height: 100,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 6, valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary)),
            Icon(Icons.payments, color: theme.colorScheme.primary, size: 40),
          ],
        ),
      );
    }
    // Generic spinner
    return SizedBox(
      width: 100,
      height: 100,
      child: CircularProgressIndicator(strokeWidth: 6, valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary)),
    );
  }

  String _processingTitle(AppLocalizations l10n) {
    switch (_transaction?.status) {
      case TransactionStatus.waiting_on_manual_approval:
        return 'Waiting on manual approval';
      case TransactionStatus.payment_in_progress:
        return 'Payment in progress';
      case TransactionStatus.waiting_on_approval:
      default:
        return l10n.translate('processing');
    }
  }

  Widget _buildCountdownChip(ThemeData theme) {
    final minutes = _manualRemaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _manualRemaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(24)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer, size: 18, color: theme.colorScheme.onSecondaryContainer),
        const SizedBox(width: 8),
        Text('$minutes:$seconds', style: context.textStyles.labelLarge?.copyWith(color: theme.colorScheme.onSecondaryContainer)),
      ]),
    );
  }
}
