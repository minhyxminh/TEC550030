import 'package:material_ui/material_ui.dart';

// The lettering is cut from the logo itself so the name always matches it.
class GymFlowWordmark extends StatelessWidget {
  final double height;
  const GymFlowWordmark({super.key, this.height = 28});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'GymFlow',
    image: true,
    child: Image.asset(
      'assets/brand/wordmark.png',
      height: height,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );
}

class TigerHead extends StatelessWidget {
  final double size;
  const TigerHead({super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/brand/tiger_head.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}
