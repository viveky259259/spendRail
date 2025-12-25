import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
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
  late final AudioPlayer _audioPlayer;
  String _selectedCurrency = 'INR';
  bool _isRecording = false;
  bool _isLoading = false;
  String? _voiceNotePath;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  final List<String> _currencies = ['INR', 'USD', 'EUR', 'GBP'];

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      setState(() => _position = p);
    });
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
        try { await _audioPlayer.stop(); } catch (e) { debugPrint('Audio stop before recording failed: $e'); }
        await _audioRecorder.start(const RecordConfig(), path: 'approval_voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
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
        if (_duration != Duration.zero && _position >= _duration) {
          await _audioPlayer.seek(Duration.zero);
        }
        await _audioPlayer.play(DeviceFileSource(_voiceNotePath!));
      }
    } catch (e) {
      debugPrint('Audio play/pause error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Unable to play voice note')),
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

  Future<void> _submitRequest() async {
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
        try { await _audioPlayer.stop(); } catch (e) { debugPrint('Audio stop before submit failed: $e'); }
      }
    } catch (e) {
      debugPrint('Failed to finalize audio before submit: $e');
    }

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
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: AppSpacing.paddingMd,
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _togglePlayPause,
                              icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: theme.colorScheme.secondary, size: 32),
                              tooltip: _isPlaying ? 'Pause' : 'Play',
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Voice note', style: context.textStyles.bodyMedium?.semiBold),
                                  SizedBox(height: 2),
                                  Text('${_formatDuration(_position)} / ${_formatDuration(_duration)}', style: context.textStyles.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            if (_position > Duration.zero && _duration > Duration.zero)
                              SizedBox(
                                width: 120,
                                child: Slider(
                                  value: _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble(),
                                  max: (_duration.inMilliseconds == 0 ? 1 : _duration.inMilliseconds).toDouble(),
                                  onChanged: (v) async {
                                    final newPos = Duration(milliseconds: v.round());
                                    try { await _audioPlayer.seek(newPos); } catch (e) { debugPrint('Seek error: $e'); }
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
