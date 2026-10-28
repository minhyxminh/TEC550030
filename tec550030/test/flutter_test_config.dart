import 'dart:async';

import 'package:tec550030/widgets/ambient.dart';
import 'package:tec550030/widgets/mascot.dart';
import 'package:tec550030/widgets/sprite_player.dart';
import 'package:tec550030/services/notification_service.dart';

// Idle loops never end, which would keep pumpAndSettle waiting.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Mascot.idleMotion = false;
  AppMotion.ambient = false;
  NotificationService.polling = false;
  SpritePlayer.animate = false;
  await testMain();
}
