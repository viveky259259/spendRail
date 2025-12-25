import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spendrail_worker_app/l10n/app_localizations.dart';
import 'package:spendrail_worker_app/services/auth_service.dart';
import 'package:spendrail_worker_app/theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizeToE164(String input) {
    final raw = input.trim();
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.startsWith('+')) return '+$digits';
    if (digits.length == 11 && digits.startsWith('0')) return '+91${digits.substring(1)}';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    if (digits.length == 10) return '+91$digits';
    if (digits.length >= 10 && digits.length <= 15) return '+$digits';
    return '+91$digits';
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final phone = _normalizeToE164(_phoneController.text);
    final authService = ref.read(authServiceProvider);
    try {
      await authService.verifyPhoneNumber(
        phone,
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          context.push('/otp', extra: {
            'verificationId': verificationId,
            'phoneNumber': phone,
            'resendToken': resendToken,
          });
        },
        verificationFailed: (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? e.code), backgroundColor: Theme.of(context).colorScheme.error),
          );
        },
        verificationCompleted: (credential) async {
          try {
            await authService.signInWithPhoneCredential(credential);
            if (!mounted) return;
            context.go('/');
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto verification failed: $e'), backgroundColor: Theme.of(context).colorScheme.error));
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          // no-op: user can still enter code manually
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send OTP: $e'), backgroundColor: Theme.of(context).colorScheme.error),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: AppSpacing.xxl),
                Icon(Icons.account_balance_wallet_rounded, size: 80, color: theme.colorScheme.primary),
                SizedBox(height: AppSpacing.lg),
                Text(l10n.translate('app_name'), style: context.textStyles.headlineLarge?.copyWith(color: theme.colorScheme.primary), textAlign: TextAlign.center),
                SizedBox(height: AppSpacing.sm),
                Text(l10n.translate('welcome_back'), style: context.textStyles.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                SizedBox(height: AppSpacing.xxl),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone number',
                    hintText: '98765 43210',
                    prefixText: '+91 ',
                    prefixIcon: Icon(Icons.phone_iphone, color: theme.colorScheme.primary),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Please enter phone number';
                    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                    if (v.startsWith('+')) {
                      if (digits.length < 10) return 'Enter valid phone number';
                      return null;
                    }
                    if (digits.length == 10 || (digits.length == 11 && digits.startsWith('0')) || (digits.length == 12 && digits.startsWith('91'))) {
                      return null; // we'll auto-attach +91
                    }
                    return 'Enter 10-digit mobile number';
                  },
                  onFieldSubmitted: (_) => _sendOtp(),
                ),
                SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  child: _isLoading
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                    : const Text('Send OTP'),
                ),
                SizedBox(height: AppSpacing.md),
                Text('We will text you a verification code. Message and data rates may apply.', style: context.textStyles.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
