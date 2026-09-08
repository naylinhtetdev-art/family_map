import 'package:flutter/material.dart';

extension ResponsiveExtension on BuildContext {
  bool get isTablet => MediaQuery.sizeOf(this).width >= 600;
}
