import 'dart:async';
import 'package:flutter/material.dart';
import '../services/transcription_service.dart';
import '../services/os_stt_service.dart';
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

enum _RecordingState { recording, transcribing, error }

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  late final TranscriptionService _stt;
  StreamSubscription<double>? _levelSub;
  Timer? _timer;

  double _level = 0;
  int _elapsed = 0;
  _RecordingState _state = _RecordingState.recording;

  @override
  void initState() {
    super.initState();
    _stt = OsSttService();
    _begin();
  }

  Future<void> _begin() async {
    final ok = await _stt.init();
    if (!mounted) return;
    if (!ok) {
      setState(() => _state = _RecordingState.error);
      return;
    }
    _levelSub = _stt.levelStream.listen((level) {
      if (mounted) setState(() => _level = level);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
    await _stt.start();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await _levelSub?.cancel();
    setState(() => _state = _RecordingState.transcribing);
    final text = await _stt.stop();
    if (!mounted) return;
    if (text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }
    await _process(text);
  }

  Future<void> _process(String text) async {
    final nav = Navigator.of(context);
    final projects = StorageService.instance.allProjects();
    final note = await FormatterService.buildNote(
      transcript: text,
      durationSeconds: _elapsed,
      projects: projects,
      apiKey: SettingsService.instance.apiKey,
    );
    await StorageService.instance.saveNote(note);
    bumpData();
    await NotificationService.instance.scheduleNoteReminders(note);
    var miko = const MikoResponse(trigger: MikoTrigger.none, message: '');
    if (SettingsService.instance.mikoEnabled) {
      final history =
          StorageService.instance.allNotes().where((n) => n.id != note.id).toList();
      miko = MikoService.react(note, history);
      if (!miko.isSilent) {
        await NotificationService.instance.showMiko('miko', miko.message);
      }
    }
    if (!mounted) return;
    nav.pushReplacement(
      MaterialPageRoute(
        builder: (_) => NoteDetailScreen(
          note: note,
          mikoResponse: miko.isSilent ? null : miko,
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    await _levelSub?.cancel();
    await _stt.cancel();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _levelSub?.cancel();
    _stt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.ramble;
    return switch (_state) {
      _RecordingState.error => _buildError(context, scheme),
      _RecordingState.transcribing => _buildTranscribing(context, scheme),
      _RecordingState.recording => _buildRecording(context, scheme),
    };
  }

  Widget _buildRecording(BuildContext context, RambleScheme scheme) {
    return Scaffold(
      backgroundColor: scheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(RambleSpace.s4),
              child: Text(
                _formatTime(_elapsed),
                style: RambleType.screenTitle(scheme.ink).copyWith(fontSize: 28),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: RambleSpace.s5,
                  horizontal: RambleSpace.s4,
                ),
                child: MikoWaveform(level: _level, height: 160, looping: false),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(RambleSpace.s5),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _stop,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: RambleColors.pixelPink,
                        shape: BoxShape.circle,
                        border: Border.all(color: RambleColors.deepNavy, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            offset: Offset(4, 4),
                            blurRadius: 0,
                            color: RambleColors.deepNavy,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.stop, color: Colors.white, size: 36),
                    ),
                  ),
                  const SizedBox(height: RambleSpace.s3),
                  Text('TAP TO STOP', style: RambleType.label(scheme.ink)),
                  const SizedBox(height: RambleSpace.s4),
                  TextButton(
                    onPressed: _cancel,
                    child: Text('cancel', style: RambleType.label(scheme.inkSoft)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscribing(BuildContext context, RambleScheme scheme) {
    return Scaffold(
      backgroundColor: scheme.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MikoCharacter(state: MikoState.processing, size: 120),
            const SizedBox(height: RambleSpace.s5),
            SizedBox(
              height: 80,
              child: MikoWaveform(level: 0, height: 80, looping: true),
            ),
            const SizedBox(height: RambleSpace.s5),
            Text('MAKING SENSE OF IT…', style: RambleType.screenTitle(scheme.ink)),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, RambleScheme scheme) {
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
