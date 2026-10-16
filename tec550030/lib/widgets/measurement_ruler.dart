import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';

class MeasurementRuler extends StatefulWidget {
  final String label, unit;
  final double value, min, max, step;
  final int majorEvery;
  final ValueChanged<double> onChanged;
  const MeasurementRuler({
    super.key,
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.majorEvery,
    required this.onChanged,
  });
  @override
  State<MeasurementRuler> createState() => _MeasurementRulerState();
}

class _MeasurementRulerState extends State<MeasurementRuler> {
  static const _spacing = 6.0;
  late final ScrollController _scroll;
  @override
  void initState() {
    super.initState();
    _scroll = ScrollController(initialScrollOffset: _offset(widget.value));
    _scroll.addListener(_changed);
  }

  double _offset(double value) =>
      ((value - widget.min) / widget.step).clamp(
        0,
        (widget.max - widget.min) / widget.step,
      ) *
      _spacing;
  void _changed() {
    final index = (_scroll.offset / _spacing).round().clamp(
      0,
      ((widget.max - widget.min) / widget.step).round(),
    );
    final value = double.parse(
      (widget.min + index * widget.step).toStringAsFixed(1),
    );
    if ((value - widget.value).abs() > 0.001) widget.onChanged(value);
  }

  @override
  void didUpdateWidget(covariant MeasurementRuler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_scroll.hasClients &&
        (_scroll.offset - _offset(widget.value)).abs() > _spacing) {
      _scroll.jumpTo(_offset(widget.value));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _adjust(double delta) {
    final value = (widget.value + delta)
        .clamp(widget.min, widget.max)
        .toDouble();
    _scroll.jumpTo(_offset(value));
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    value:
        '${widget.value.toStringAsFixed(widget.step < 1 ? 1 : 0)} ${widget.unit}',
    increasedValue:
        '${(widget.value + widget.step).clamp(widget.min, widget.max).toStringAsFixed(widget.step < 1 ? 1 : 0)} ${widget.unit}',
    decreasedValue:
        '${(widget.value - widget.step).clamp(widget.min, widget.max).toStringAsFixed(widget.step < 1 ? 1 : 0)} ${widget.unit}',
    onIncrease: () => _adjust(widget.step),
    onDecrease: () => _adjust(-widget.step),
    child: LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ExcludeSemantics(
              child: ListView.builder(
                key: ValueKey('ruler-scroll-${widget.unit}'),
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemExtent: _spacing,
                padding: EdgeInsets.symmetric(
                  horizontal: (constraints.maxWidth - _spacing) / 2,
                ),
                itemCount:
                    ((widget.max - widget.min) / widget.step).round() + 1,
                itemBuilder: (context, index) => CustomPaint(
                  painter: _TickPainter(
                    value: widget.min + index * widget.step,
                    major: index % widget.majorEvery == 0,
                    medium: index % (widget.majorEvery ~/ 2) == 0,
                    textDirection: Directionality.of(context),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Container(
                width: 2,
                height: 66,
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TickPainter extends CustomPainter {
  final double value;
  final bool major, medium;
  final TextDirection textDirection;
  const _TickPainter({
    required this.value,
    required this.major,
    required this.medium,
    required this.textDirection,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.secondaryText.withValues(alpha: major ? 0.6 : 0.22)
      ..strokeWidth = major ? 2 : 1;
    canvas.drawLine(
      Offset(
        size.width / 2,
        major
            ? 30
            : medium
            ? 40
            : 46,
      ),
      Offset(size.width / 2, 64),
      paint,
    );
    if (major) {
      final text = TextPainter(
        text: TextSpan(
          text: value.toStringAsFixed(0),
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 12,
            fontFamily: 'Roboto',
          ),
        ),
        textDirection: textDirection,
      )..layout();
      text.paint(canvas, Offset((size.width - text.width) / 2, 4));
    }
  }

  @override
  bool shouldRepaint(covariant _TickPainter old) =>
      value != old.value ||
      major != old.major ||
      textDirection != old.textDirection;
}
