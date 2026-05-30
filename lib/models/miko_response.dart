/// Why Miko spoke up. Drives his face state and the response card styling.
enum MikoTrigger {
  firstInProject, // excited
  repeatedTask, // contradiction-ish, raised brow
  connection, // talking back
  recurringTheme, // pattern
  staleReactivated, // talking back
  contradiction, // contradiction face
  none, // Miko stays silent
}

/// A single thing Miko says back after processing a note. The active response
/// system produces at most one of these per note; [trigger] == none means
/// Miko stays quiet (render nothing).
class MikoResponse {
  final MikoTrigger trigger;
  final String message; // lowercase, dry, in Miko's voice
  final String? relatedNoteId; // for "see them together" actions

  const MikoResponse({
    required this.trigger,
    required this.message,
    this.relatedNoteId,
  });

  bool get isSilent => trigger == MikoTrigger.none;

  static const silent = MikoResponse(trigger: MikoTrigger.none, message: '');
}
