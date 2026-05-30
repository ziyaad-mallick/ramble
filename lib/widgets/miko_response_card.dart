import 'package:flutter/material.dart';
import '../theme/ramble_theme.dart';
import '../models/miko_response.dart';
import 'miko/miko_character.dart';
import 'miko/miko_painter.dart';

class MikoResponseCard extends StatelessWidget {
  final MikoResponse response;
  final VoidCallback? onDismiss;
  final VoidCallback? onRelated;

  const MikoResponseCard({
    super.key,
    required this.response,
    this.onDismiss,
    this.onRelated,
  });

  MikoState _stateFromTrigger(MikoTrigger trigger) {
    switch (trigger) {
      case MikoTrigger.contradiction:
        return MikoState.contradiction;
      case MikoTrigger.connection:
      case MikoTrigger.staleReactivated:
        return MikoState.talking;
      case MikoTrigger.firstInProject:
        return MikoState.excited;
      case MikoTrigger.repeatedTask:
        return MikoState.contradiction;
      case MikoTrigger.recurringTheme:
        return MikoState.talking;
      case MikoTrigger.none:
        return MikoState.idle;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (response.isSilent) {
      return const SizedBox.shrink();
    }

    final scheme = context.ramble;
    final mikoState = _stateFromTrigger(response.trigger);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RambleColors.deepNavy,
        borderRadius: BorderRadius.circular(RambleGeo.cardRadius),
        border: Border.all(
          color: RambleColors.mikoPurple,
          width: RambleGeo.borderWidth,
        ),
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Miko character on left
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: MikoCharacter(
                  state: mikoState,
                  size: 40,
                ),
              ),
              // Message and related link on right
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      response.message,
                      style: RambleType.mikoMessage(Colors.white),
                    ),
                    if (response.relatedNoteId != null && onRelated != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: onRelated,
                        child: Text(
                          'see it →',
                          style: RambleType.mikoMessage(RambleColors.pixelPink),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // Dismiss button top-right
          if (onDismiss != null)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: onDismiss,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
