import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
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
  late final AudioPlayer _audioPlayer;
  bool _isRecording = false;
  bool _isLoading = false;
  String? _voiceNotePath;
  String? _vpa; // Extracted from UPI QR (param 'pa')
  String? _payeeName; // Optional: extracted 'pn'
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Stream subscriptions for audio player
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  @override
  void dispose() {
    // Cancel stream subscriptions to prevent setState after dispose
    _playerStateSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _amountController.dispose();
    _noteController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _parseUpiData(widget.qrData);
    _audioPlayer = AudioPlayer();
    // Listen to audio player state and durations with proper subscription management
    _playerStateSubscription =
        _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _durationSubscription = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _positionSubscription = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  void _parseUpiData(String data) {
    try {
      final raw = data.trim();
      Uri? uri;
      // Some scanners might omit the scheme; normalize if needed
      if (raw.contains('://')) {
        uri = Uri.tryParse(raw);
      } else if (raw.startsWith('upi/pay?') || raw.startsWith('pay?')) {
        uri = Uri.tryParse('upi://$raw');
      } else {
        uri = Uri.tryParse(raw);
      }

      // Primary: use Uri queryParameters
      String? vpa = uri?.queryParameters['pa'];
      String? pn = uri?.queryParameters['pn'];

      // Fallback: regex extraction if Uri fails
      if ((vpa == null || vpa.isEmpty) && raw.contains('pa=')) {
        final match = RegExp(r'(?:^|[?&])pa=([^&]+)').firstMatch(raw);
        if (match != null && match.groupCount >= 1) {
          vpa = Uri.decodeComponent(match.group(1)!);
        }
      }
      if ((pn == null || pn.isEmpty) && raw.contains('pn=')) {
        final match = RegExp(r'(?:^|[?&])pn=([^&]+)').firstMatch(raw);
        if (match != null && match.groupCount >= 1) {
          pn = Uri.decodeComponent(match.group(1)!);
        }
      }

      setState(() {
        _vpa = vpa;
        _payeeName = pn;
      });

      debugPrint('Parsed UPI: pa=$_vpa, pn=$_payeeName from: $raw');
    } catch (e) {
      debugPrint('Failed to parse UPI QR data: $e');
    }
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
        // Stop any currently playing audio before starting a new recording
        try {
          await _audioPlayer.stop();
        } catch (e) {
          debugPrint('Audio stop before recording failed: $e');
        }
        await _audioRecorder.start(const RecordConfig(),
            path: 'voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a');
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_voiceNotePath == null) return;
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        // If playback finished previously, restart from beginning
        if (_duration != Duration.zero && _position >= _duration) {
          await _audioPlayer.seek(Duration.zero);
        }
        await _audioPlayer.play(DeviceFileSource(_voiceNotePath!));
      }
    } catch (e) {
      debugPrint('Audio play/pause error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Unable to play voice note'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final two = (int n) => n.toString().padLeft(2, '0');
    final minutes = two(d.inMinutes.remainder(60));
    final seconds = two(d.inSeconds.remainder(60));
    final hours = d.inHours;
    return hours > 0 ? '${two(hours)}:$minutes:$seconds' : '$minutes:$seconds';
  }

  Future<void> _submitPayment() async {
    // Ensure any ongoing recording/playback is stopped before submitting
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        setState(() {
          _isRecording = false;
          _voiceNotePath = path;
        });
      }
      if (_isPlaying) {
        try {
          await _audioPlayer.stop();
        } catch (e) {
          debugPrint('Audio stop before submit failed: $e');
        }
      }
    } catch (e) {
      debugPrint('Failed to finalize audio before submit: $e');
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final paymentService = ref.read(paymentServiceProvider);
      final userId = authService.currentUser?.uid;

      if (userId == null) throw Exception('User not logged in');

      // Upload voice note to Firebase Storage if available
      String? voiceNoteUrl;
      if (_voiceNotePath != null && _voiceNotePath!.isNotEmpty) {
        try {
          final file = File(_voiceNotePath!);
          final ext = _voiceNotePath!.split('.').last.toLowerCase();
          final contentType = ext == 'm4a'
              ? 'audio/m4a'
              : (ext == 'aac' ? 'audio/aac' : 'audio/mp4');
          final ref = FirebaseStorage.instance.ref().child(
              'voice_notes/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext');
          final uploadTask = await ref.putFile(
            file,
            SettableMetadata(contentType: contentType),
          );
          voiceNoteUrl = await uploadTask.ref.getDownloadURL();
        } catch (e) {
          debugPrint('Voice note upload failed: $e');
          // Continue without voice note rather than failing entire payment
        }
      }

      final amount = double.parse(_amountController.text);

      final firebaseId = await paymentService.initiatePayment(
        userId: userId,
        amount: amount,
        qrData: widget.qrData,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        voiceNoteUrl: voiceNoteUrl,
      );

      // If amount > 200, ask user to upload invoice image now (optional)
      if (amount > 200) {
        if (mounted) {
          final theme = Theme.of(context);
          final action = await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            builder: (ctx) => Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Invoice required for amounts above ₹200',
                      style: context.textStyles.titleMedium?.semiBold),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Upload your purchase invoice now or do it later from History.',
                    style: context.textStyles.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(ctx).pop('upload'),
                    icon: Icon(Icons.upload_file,
                        color: theme.colorScheme.onPrimary),
                    label: Text('Upload invoice now'),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop('skip'),
                    icon: Icon(Icons.schedule, color: theme.colorScheme.primary),
                    label: Text('Do it later'),
                  ),
                ],
              ),
            ),
          );

          if (action == 'upload') {
            try {
              final picker = ImagePicker();
              final image = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 1920,
                imageQuality: 85,
              );
              if (image != null) {
                // Show a quick loading dialog while uploading
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
                    firebaseId: firebaseId,
                    userId: userId,
                    data: bytes,
                    filename: image.name,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Invoice uploaded successfully')),
                    );
                  }
                } catch (e) {
                  debugPrint('Invoice upload from form failed: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Invoice upload failed. You can upload from History.'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                } finally {
                  if (mounted) Navigator.of(context, rootNavigator: true).pop();
                }
              }
            } catch (e) {
              debugPrint('Image pick failed: $e');
            }
          }
        }
      }

      if (mounted) context.go('/payment-processing', extra: firebaseId);
    } catch (e) {
      debugPrint('Payment submission error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Payment failed: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error),
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
                        Icon(Icons.qr_code_2,
                            size: 64, color: theme.colorScheme.primary),
                        SizedBox(height: AppSpacing.md),
                        Text('QR Code Scanned',
                            style: context.textStyles.titleMedium?.semiBold),
                        SizedBox(height: AppSpacing.sm),
                        if (_vpa != null && _vpa!.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.alternate_email,
                                  size: 18, color: theme.colorScheme.primary),
                              SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text(
                                  _vpa!,
                                  style: context.textStyles.bodyMedium
                                      ?.copyWith(
                                          color: theme.colorScheme.onSurface),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (_payeeName != null && _payeeName!.isNotEmpty) ...[
                            SizedBox(height: AppSpacing.xs),
                            Text(
                              _payeeName!,
                              style: context.textStyles.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ] else ...[
                          Text(
                            widget.qrData,
                            style: context.textStyles.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: l10n.translate('amount'),
                    prefixIcon: Icon(Icons.currency_rupee,
                        color: theme.colorScheme.primary),
                    hintText: '0.00',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter amount';
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0)
                      return 'Please enter valid amount';
                    return null;
                  },
                ),
                SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: l10n.translate('note'),
                    prefixIcon: Icon(Icons.note_outlined,
                        color: theme.colorScheme.primary),
                    hintText: 'Optional',
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _toggleRecording,
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic,
                      color: _isRecording
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary),
                  label: Text(_isRecording
                      ? 'Stop Recording'
                      : (_voiceNotePath != null
                          ? 'Voice Note Recorded'
                          : l10n.translate('record_voice'))),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: _isRecording
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                        width: 2),
                    foregroundColor: _isRecording
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
                if (_voiceNotePath != null)
                  Padding(
                    padding: EdgeInsets.only(top: AppSpacing.sm),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: AppSpacing.paddingMd,
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _togglePlayPause,
                              icon: Icon(
                                  _isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_fill,
                                  color: theme.colorScheme.primary,
                                  size: 32),
                              tooltip: _isPlaying ? 'Pause' : 'Play',
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Voice note',
                                      style: context
                                          .textStyles.bodyMedium?.semiBold),
                                  SizedBox(height: 2),
                                  Text(
                                      '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                                      style: context.textStyles.labelSmall
                                          ?.copyWith(
                                              color: theme.colorScheme
                                                  .onSurfaceVariant)),
                                ],
                              ),
                            ),
                            if (_position > Duration.zero &&
                                _duration > Duration.zero)
                              SizedBox(
                                width: 120,
                                child: Slider(
                                  value: _position.inMilliseconds
                                      .clamp(0, _duration.inMilliseconds)
                                      .toDouble(),
                                  max: (_duration.inMilliseconds == 0
                                          ? 1
                                          : _duration.inMilliseconds)
                                      .toDouble(),
                                  onChanged: (v) async {
                                    final newPos =
                                        Duration(milliseconds: v.round());
                                    try {
                                      await _audioPlayer.seek(newPos);
                                    } catch (e) {
                                      debugPrint('Seek error: $e');
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitPayment,
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary))
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
