import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:spendrail_worker_app/l10n/app_localizations.dart';
import 'package:spendrail_worker_app/services/auth_service.dart';
import 'package:spendrail_worker_app/services/payment_service.dart';
import 'package:spendrail_worker_app/theme.dart';

class PaymentFormScreen extends ConsumerStatefulWidget {
  final String qrData;

  const PaymentFormScreen({super.key, required this.qrData});

  @override
  ConsumerState<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends ConsumerState<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isLoading = false;
  String? _voiceNotePath;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _voiceNotePath = path;
      });
    } else {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(const RecordConfig(), path: 'voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a');
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final paymentService = ref.read(paymentServiceProvider);
      final userId = authService.currentUser?.uid;

      if (userId == null) throw Exception('User not logged in');

      final firebaseId = await paymentService.initiatePayment(
        userId: userId,
        amount: double.parse(_amountController.text),
        qrData: widget.qrData,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        voiceNoteUrl: _voiceNotePath,
      );

      if (mounted) {
        context.go('/payment-processing', extra: firebaseId);
      }
    } catch (e) {
      debugPrint('Payment submission error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('pay_now')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: AppSpacing.paddingLg,
                    child: Column(
                      children: [
                        Icon(Icons.qr_code_2, size: 64, color: theme.colorScheme.primary),
                        SizedBox(height: AppSpacing.md),
                        Text('QR Code Scanned', style: context.textStyles.titleMedium?.semiBold),
                        SizedBox(height: AppSpacing.sm),
                        Text(widget.qrData, style: context.textStyles.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: l10n.translate('amount'),
                    prefixIcon: Icon(Icons.currency_rupee, color: theme.colorScheme.primary),
                    hintText: '0.00',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter amount';
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) return 'Please enter valid amount';
                    return null;
                  },
                ),
                SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: l10n.translate('note'),
                    prefixIcon: Icon(Icons.note_outlined, color: theme.colorScheme.primary),
                    hintText: 'Optional',
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _toggleRecording,
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic, color: _isRecording ? theme.colorScheme.error : theme.colorScheme.primary),
                  label: Text(_isRecording ? 'Stop Recording' : (_voiceNotePath != null ? 'Voice Note Recorded' : l10n.translate('record_voice'))),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _isRecording ? theme.colorScheme.error : theme.colorScheme.primary, width: 2),
                    foregroundColor: _isRecording ? theme.colorScheme.error : theme.colorScheme.primary,
                  ),
                ),
                if (_voiceNotePath != null)
                  Padding(
                    padding: EdgeInsets.only(top: AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 16),
                        SizedBox(width: AppSpacing.xs),
                        Text('Voice note recorded', style: context.textStyles.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                      ],
                    ),
                  ),
                SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitPayment,
                  child: _isLoading
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                    : Text(l10n.translate('submit')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
