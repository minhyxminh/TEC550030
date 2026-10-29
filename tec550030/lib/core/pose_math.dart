import 'dart:math' as math;

/// Calculates the joint angle at B (formed by ray BA and ray BC) in degrees [0, 180].
double angleDeg(
  ({double x, double y}) a,
  ({double x, double y}) b,
  ({double x, double y}) c,
) {
  final bax = a.x - b.x;
  final bay = a.y - b.y;
  final bcx = c.x - b.x;
  final bcy = c.y - b.y;

  final dot = bax * bcx + bay * bcy;
  final magBA = math.sqrt(bax * bax + bay * bay);
  final magBC = math.sqrt(bcx * bcx + bcy * bcy);

  if (magBA == 0 || magBC == 0) return 0;

  final cosVal = (dot / (magBA * magBC)).clamp(-1.0, 1.0);
  return math.acos(cosVal) * 180 / math.pi;
}

