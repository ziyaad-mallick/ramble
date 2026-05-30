import 'dart:async';
import 'package:flutter/material.dart';
import '../services/speech_service.dart';
import '../services/formatter_service.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';
import '../services/miko_service.dart';
import '../services/notification_service.dart';
import '../services/app_events.dart';
import '../models/miko_response.dart';
import '../theme/ramble_theme.dart';
import '../widgets/miko/miko_waveform.dart';
import '../widgets/miko/miko_character.dart';
import '../widgets/miko/miko_painter.dart';
import '../widgets/ramble_button.dart';
import 'note_detail_screen.dart';

enum _RecordingState { listening, processing, error }

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  late SpeechService _speech;
  String _transcript = '';
  double _level = 0;
  int _elapsed = 0;
  Timer? _timer;
  _RecordingState _state = _RecordingState.listening;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  /// Initialize speech service and start listening.
  Future<void> _begin() async {
    _speech = SpeechService();
    final ok = await _speech.init();

    if (!mounted) return;

    if (!ok) {
      setState(() => _state = _RecordingState.error);
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsed++);
      }
    });

    await _speech.start(
      onPartial: (transcript) {
        if (mounted) {
          setState(() => _transcript = transcript);
        }
      },
      onLevel: (level) {
        if (mounted) {
          setState(() => _level = ((level + 2) / 12).clamp(0, 1));
        }
      },
    );
  }

  /// Format time as mm:ss
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Stop recording and process transcript
  Future<void> _stop() async {
    _timer?.cancel();
    final text = await _speech.stop();

    if (!mounted) return;

    if (text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() => _state = _RecordingState.processing);
    await _process(text);
  }

  /// Process the transcript: format note, save, trigger Miko, navigate
  Future<void> _process(String text) async {
    final nav = Navigator.of(context);
    final projects = StorageService.instance.allProjects();

    // Build the note from transcript
    final note = await FormatterService.buildNote(
      transcript: text,
      durationSeconds: _elapsed,
      projects: projects,
      apiKey: SettingsService.instance.apiKey,
    );

    // Save the note to storage
    await StorageService.instance.saveNote(note);

    // Bump global data version so lists rebuild
    bumpData();

    // Schedule any reminders extracted from the note
    await NotificationService.instance.scheduleNoteReminders(note);

    // Get Miko's reaction (if enabled)
    var miko = const MikoResponse(
      trigger: MikoTrigger.none,
      message: '',
    );

    if (SettingsService.instance.mikoEnabled) {
      final history =
          StorageService.instance.allNotes().where((n) => n.id != note.id).toList();
      miko = MikoService.react(note, history);

      // If Miko has something to say, show a notification
      if (!miko.isSilent) {
        await NotificationService.instance.showMiko('miko', miko.message);
      }
    }

    if (!mounted) return;

    // Navigate to detail screen with the new note
    nav.pushReplacement(
      MaterialPageRoute(
        builder: (_) => NoteDetailScreen(
          note: note,
          mikoResponse: miko.isSilent ? null : miko,
        ),
      ),
    );
  }

  /// Cancel recording and pop
  Future<void> _cancel() async {
    _timer?.cancel();
    await _speech.cancel();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_speech.isListening) {
      _speech.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.ramble;

    // Render based on state
    if (_state == _RecordingState.error) {
      return _buildErrorUI(context, scheme);
    }

    if (_state == _RecordingState.processing) {
      return _buildProcessingUI(context, scheme);
    }

    // Default: listening state
    return _buildListeningUI(context, scheme);
  }

  /// LISTENING UI: timer + waveform + transcript area + stop button
  Widget _buildListeningUI(BuildContext context, RambleScheme scheme) {
    return Scaffold(
      backgroundColor: scheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Timer at top
            Padding(
              padding: const EdgeInsets.all(RambleSpace.s4),
              child: Text(
                _formatTime(_elapsed),
                style: RambleType.screenTitle(scheme.ink).copyWith(fontSize: 28),
              ),
            ),

            // Waveform in center
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: RambleSpace.s5,
                horizontal: RambleSpace.s4,
              ),
              child: MikoWaveform(
                level: _level,
                height: 160,
                looping: false,
              ),
            ),

            // Transcript area (expanded)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: RambleSpace.s4),
                child: SingleChildScrollView(
                  child: _transcript.isEmpty
                      ? Text(
                          'listening…',
                          style:
                              RambleType.body(scheme.inkSoft).copyWith(fontStyle: FontStyle.italic),
                        )
                      : Text(
                          _transcript,
                          style: RambleType.body(scheme.ink),
                        ),
                ),
              ),
            ),

            // Stop button + cancel link at bottom
            Padding(
              padding: const EdgeInsets.all(RambleSpace.s5),
              child: Column(
                children: [
                  // Circular stop button
                  GestureDetector(
                    onTap: _stop,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: RambleColors.pixelPink,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: RambleColors.deepNavy,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            offset: const Offset(4, 4),
                            blurRadius: 0,
                            color: RambleColors.deepNavy,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.stop,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: RambleSpace.s3),
                  Text(
                    'TAP TO STOP',
                    style: RambleType.label(scheme.ink),
                  ),
                  const SizedBox(height: RambleSpace.s4),
                  TextButton(
                    onPressed: _cancel,
                    child: Text(
                      'cancel',
                      style: RambleType.label(scheme.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PROCESSING UI: Miko character + waveform looping + status text
  Widget _buildProcessingUI(BuildContext context, RambleScheme scheme) {
    return Scaffold(
      backgroundColor: scheme.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Miko character in processing state
            MikoCharacter(
              state: MikoState.processing,
              size: 120,
            ),
            const SizedBox(height: RambleSpace.s5),

            // Looping waveform
            SizedBox(
              height: 80,
              child: MikoWaveform(
                level: 0,
                height: 80,
                looping: true,
              ),
            ),
            const SizedBox(height: RambleSpace.s5),

            // Status text
            Text(
              'MAKING SENSE OF IT…',
              style: RambleType.screenTitle(scheme.ink),
            ),
          ],
        ),
      ),
    );
  }

  /// ERROR UI: error message + go back button
  Widget _buildErrorUI(BuildContext context, RambleScheme scheme) {
    return Scaffold(
      backgroundColor: scheme.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(RambleSpace.s5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "couldn't reach the mic",
                textAlign: TextAlign.center,
                style: RambleType.screenTitle(scheme.ink),
              ),
              const SizedBox(height: RambleSpace.s6),
              RambleButton(
                label: 'GO BACK',
                onTap: () => Navigator.pop(context),
                kind: RambleButtonKind.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
