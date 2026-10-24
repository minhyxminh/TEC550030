import 'dart:async';

import 'package:tec550030/widgets/ambient.dart';
import 'package:tec550030/widgets/mascot.dart';

// Idle loops never end, which would keep pumpAndSettle waiting.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Mascot.idleMotion = false;
  AppMotion.ambient = false;
  await testMain();
}
