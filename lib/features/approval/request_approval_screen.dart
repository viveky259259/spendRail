import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:spendrail_worker_app/l10n/app_localizations.dart';
import 'package:spendrail_worker_app/services/approval_service.dart';
import 'package:spendrail_worker_app/services/auth_service.dart';
import 'package:spendrail_worker_app/theme.dart';

class RequestApprovalScreen extends ConsumerStatefulWidget {
  const RequestApprovalScreen({super.key});

  @override
  ConsumerState<RequestApprovalScreen> createState() => _RequestApprovalScreenState();
}

class _RequestApprovalScreenState extends ConsumerState<RequestApprovalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _audioRecorder = AudioRecorder();
  String _selectedCurrency = 'INR';
  bool _isRecording = false;
  bool _isLoading = false;
  String? _voiceNotePath;

  final List<String> _currencies = ['INR', 'USD', 'EUR', 'GBP'];

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
        await _audioRecorder.start(const RecordConfig(), path: 'approval_voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final approvalService = ref.read(approvalServiceProvider);
      final userId = authService.currentUser?.uid;

      if (userId == null) throw Exception('User not logged in');

      await approvalService.createApprovalRequest(
        userId: userId,
        amount: double.parse(_amountController.text),
        currency: _selectedCurrency,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        voiceNoteUrl: _voiceNotePath,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Approval request submitted successfully')),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('Approval request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request failed: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('request_approval')),
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
                        Icon(Icons.approval_rounded, size: 64, color: theme.colorScheme.secondary),
                        SizedBox(height: AppSpacing.md),
                        Text('Request Spending Approval', style: context.textStyles.titleMedium?.semiBold),
                        SizedBox(height: AppSpacing.sm),
                        Text('Submit your request for manager approval', style: context.textStyles.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: l10n.translate('amount'),
                          prefixIcon: Icon(Icons.currency_rupee, color: theme.colorScheme.secondary),
                          hintText: '0.00',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Enter amount';
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) return 'Invalid amount';
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCurrency,
                        decoration: InputDecoration(
                          labelText: l10n.translate('currency'),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        ),
                        items: _currencies.map((currency) => DropdownMenuItem(
                          value: currency,
                          child: Text(currency),
                        )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedCurrency = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: l10n.translate('note'),
                    prefixIcon: Icon(Icons.note_outlined, color: theme.colorScheme.secondary),
                    hintText: 'Describe your request',
                  ),
                  maxLines: 4,
                ),
                SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _toggleRecording,
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic, color: _isRecording ? theme.colorScheme.error : theme.colorScheme.secondary),
                  label: Text(_isRecording ? 'Stop Recording' : (_voiceNotePath != null ? 'Voice Note Recorded' : l10n.translate('record_voice'))),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _isRecording ? theme.colorScheme.error : theme.colorScheme.secondary, width: 2),
                    foregroundColor: _isRecording ? theme.colorScheme.error : theme.colorScheme.secondary,
                  ),
                ),
                if (_voiceNotePath != null)
                  Padding(
                    padding: EdgeInsets.only(top: AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: theme.colorScheme.secondary, size: 16),
                        SizedBox(width: AppSpacing.xs),
                        Text('Voice note recorded', style: context.textStyles.bodySmall?.copyWith(color: theme.colorScheme.secondary)),
                      ],
                    ),
                  ),
                SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: theme.colorScheme.onSecondary,
                  ),
                  child: _isLoading
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onSecondary))
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
