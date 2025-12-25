import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spendrail_worker_app/services/auth_service.dart';
import 'package:spendrail_worker_app/theme.dart';

class OTPVerificationScreen extends ConsumerStatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final int? resendToken;
  const OTPVerificationScreen({super.key, required this.verificationId, required this.phoneNumber, this.resendToken});

  @override
  ConsumerState<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends ConsumerState<OTPVerificationScreen> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _canResend = false;
  String _verificationId = '';
  int? _resendToken;
  Timer? _timer;
  int _seconds = 60;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
    _startTimer();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _seconds = 60;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_seconds == 0) {
        timer.cancel();
        setState(() => _canResend = true);
      } else {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Enter 6-digit code')));
      return;
    }
    setState(() => _isVerifying = true);
    try {
      await ref.read(authServiceProvider).signInWithSmsCode(_verificationId, code);
      if (!mounted) return;
      context.go('/');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? e.code), backgroundColor: Theme.of(context).colorScheme.error));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification failed: $e'), backgroundColor: Theme.of(context).colorScheme.error));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    setState(() => _canResend = false);
    try {
      await ref.read(authServiceProvider).verifyPhoneNumber(
        widget.phoneNumber,
        forceResendingToken: _resendToken,
        codeSent: (verificationId, resendToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
          });
          _startTimer();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP resent')));
        },
        verificationFailed: (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? e.code), backgroundColor: Theme.of(context).colorScheme.error));
        },
        verificationCompleted: (credential) async {
          try {
            await ref.read(authServiceProvider).signInWithPhoneCredential(credential);
            if (!mounted) return;
            context.go('/');
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto verified failed: $e'), backgroundColor: Theme.of(context).colorScheme.error));
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
          setState(() {});
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Resend failed: $e'), backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Enter OTP')),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text('We sent a 6-digit code to', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(widget.phoneNumber, style: theme.textTheme.titleLarge),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                maxLength: 6,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  counterText: '',
                  labelText: 'OTP Code',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isVerifying ? null : _verify,
                child: _isVerifying
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                    : const Text('Verify and Continue'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _canResend ? _resend : null,
                child: Text(_canResend ? 'Resend code' : 'Resend in 0:${_seconds.toString().padLeft(2, '0')}'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
