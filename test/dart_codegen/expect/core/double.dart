part of dart.core;

abstract class double extends num {
  static const double NAN = 0.0 / 0.0;
  static const double INFINITY = 1.0 / 0.0;
  static const double NEGATIVE_INFINITY = -INFINITY;
  static const double MIN_POSITIVE = 5e-324;
  static const double MAX_FINITE = 1.7976931348623157e+308;
  double remainder(num other);
  double operator +(num other);
  double operator -(num other);
  double operator *(num other);
  double operator %(num other);
  double operator /(num other);
  int operator ~/(num other);
  double operator -();
  double abs();
  double get sign;
  int round();
  int floor();
  int ceil();
  int truncate();
  double roundToDouble();
  double floorToDouble();
  double ceilToDouble();
  double truncateToDouble();
  String toString();
  external static double parse(String source, [double onError(String source)]);
}