import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tec550030/screens/auth/register_screen.dart';
import 'package:tec550030/widgets/camera_torch_button.dart';

void main() {
  testWidgets(
    'register eye controls independently reveal passwords without losing input',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(2), 'password123');
      await tester.enterText(fields.at(3), 'password123');
      final password = find.descendant(
        of: fields.at(2),
        matching: find.byType(EditableText),
      );
      final confirmation = find.descendant(
        of: fields.at(3),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(password).obscureText, isTrue);
      expect(tester.widget<EditableText>(confirmation).obscureText, isTrue);
      await tester.ensureVisible(find.byTooltip('Hiện mật khẩu'));
      await tester.tap(find.byTooltip('Hiện mật khẩu'));
      await tester.pump();
      expect(tester.widget<EditableText>(password).obscureText, isFalse);
      expect(tester.widget<EditableText>(confirmation).obscureText, isTrue);
      await tester.ensureVisible(find.byTooltip('Hiện nhập lại mật khẩu'));
      await tester.tap(find.byTooltip('Hiện nhập lại mật khẩu'));
      await tester.pump();
      expect(tester.widget<EditableText>(confirmation).obscureText, isFalse);
      expect(
        tester.widget<EditableText>(password).controller.text,
        'password123',
      );
      expect(
        tester.widget<EditableText>(confirmation).controller.text,
        'password123',
      );
      await tester.tap(find.byTooltip('Ẩn mật khẩu'));
      await tester.pump();
      expect(tester.widget<EditableText>(password).obscureText, isTrue);
    },
  );

  testWidgets(
    'flash follows live camera state and disables an unavailable torch',
    (tester) async {
      final controller = MobileScannerController(autoStart: false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CameraTorchButton(controller: controller)),
        ),
      );
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      controller.value = controller.value.copyWith(
        isInitialized: true,
        isRunning: true,
        torchState: TorchState.off,
      );
      await tester.pump();
      expect(find.byIcon(Icons.flash_on), findsOneWidget);
      expect(find.byTooltip('Bật flash'), findsOneWidget);
      controller.value = controller.value.copyWith(torchState: TorchState.on);
      await tester.pump();
      expect(find.byIcon(Icons.flash_off), findsOneWidget);
      expect(find.byTooltip('Tắt flash'), findsOneWidget);
      controller.value = controller.value.copyWith(
        torchState: TorchState.unavailable,
      );
      await tester.pump();
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      await controller.dispose();
    },
  );
}
