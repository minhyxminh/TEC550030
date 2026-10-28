import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// Numbered frames of one clip, e.g. `assets/battle/win/ho-thang-001.webp`.
List<String> spriteFrames(String folder, String name, int count) => [
  for (var i = 1; i <= count; i++)
    'assets/$folder/$name-${i.toString().padLeft(3, '0')}.webp',
];

enum SpriteLoop { once, loop, pingPong }

/// Decodes frames at display size ahead of time so playback never flashes.
/// Completes once every frame is ready.
Future<void> precacheSprites(
  BuildContext context,
  Iterable<String> frames, {
  double width = 360,
  int maxPixels = 480,
}) {
  final provider = spriteProvider(context, width, maxPixels: maxPixels);
  return Future.wait([
    for (final path in frames)
      precacheImage(provider(path), context, onError: (_, _) {}),
  ]);
}

/// Decoded size is capped so a whole clip fits in the image cache.
ImageProvider Function(String) spriteProvider(
  BuildContext context,
  double width, {
  int maxPixels = 480,
}) {
  final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
  final cache = ((width * dpr / 64).ceil() * 64).clamp(64, maxPixels);
  return (path) =>
      ResizeImage(AssetImage(path), width: cache, allowUpscaling: false);
}

/// Plays a frame sequence like a short video.
class SpritePlayer extends StatefulWidget {
  /// Endless playback; widget tests switch it off.
  static bool animate = true;

  final List<String> frames;
  final double fps;
  final SpriteLoop loop;

  /// Frame shown when animations are off (defaults to the last one).
  final int? stillFrame;
  final VoidCallback? onComplete;
  final ValueChanged<int>? onFrame;
  final double width;
  final BoxFit fit;

  const SpritePlayer({
    super.key,
    required this.frames,
    this.fps = 24,
    this.loop = SpriteLoop.loop,
    this.stillFrame,
    this.onComplete,
    this.onFrame,
    this.width = 360,
    this.fit = BoxFit.contain,
  });

  static bool still(BuildContext context) =>
      !animate || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  State<SpritePlayer> createState() => _SpritePlayerState();
}

class _SpritePlayerState extends State<SpritePlayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  int _frame = 0;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheSprites(context, widget.frames, width: widget.width);
    _restart();
  }

  @override
  void didUpdateWidget(covariant SpritePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.frames, widget.frames) &&
        oldWidget.frames.join() != widget.frames.join()) {
      precacheSprites(context, widget.frames, width: widget.width);
      _restart();
    }
  }

  void _restart() {
    _ticker.stop();
    _done = false;
    if (SpritePlayer.still(context)) {
      _frame = (widget.stillFrame ?? widget.frames.length - 1).clamp(
        0,
        widget.frames.length - 1,
      );
      if (widget.loop == SpriteLoop.once && widget.onComplete != null) {
        // Still mode: give the frame a moment, then report completion.
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) widget.onComplete!();
        });
      }
      return;
    }
    _frame = 0;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final n = widget.frames.length;
    final step = (elapsed.inMicroseconds * widget.fps / 1e6).floor();
    int frame;
    switch (widget.loop) {
      case SpriteLoop.once:
        frame = step.clamp(0, n - 1);
        if (step >= n && !_done) {
          _done = true;
          _ticker.stop();
          widget.onComplete?.call();
        }
      case SpriteLoop.loop:
        frame = step % n;
      case SpriteLoop.pingPong:
        final period = n <= 1 ? 1 : 2 * (n - 1);
        final p = step % period;
        frame = p < n ? p : period - p;
    }
    if (frame != _frame) {
      setState(() => _frame = frame);
      widget.onFrame?.call(frame);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Image(
    image: spriteProvider(context, widget.width)(widget.frames[_frame]),
    width: widget.width,
    fit: widget.fit,
    gaplessPlayback: true,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => SizedBox(width: widget.width),
  );
}
