import 'package:flutter/foundation.dart';

/// Global data-version notifier. Any write to storage bumps this; screens that
/// show lists listen to it and rebuild. Keeps state management trivial and
/// avoids heavier patterns for the vertical slice.
final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);

void bumpData() => dataVersion.value++;
