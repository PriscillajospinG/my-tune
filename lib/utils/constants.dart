import 'package:flutter/material.dart';

class AppConstants {
  static const double bottomNavHeight = 60.0;
  static const double miniPlayerHeight = 70.0;

  // Default placeholder gradient colors for albums without art
  static const List<List<Color>> placeholderGradients = [
    [Color(0xFF6C63FF), Color(0xFF3A3A8C)],
    [Color(0xFF00D4FF), Color(0xFF005F80)],
    [Color(0xFFFF6B6B), Color(0xFF8C2020)],
    [Color(0xFF4CAF50), Color(0xFF1B5E20)],
    [Color(0xFFFF9800), Color(0xFF6D3B00)],
    [Color(0xFFE040FB), Color(0xFF4A0080)],
  ];

  static List<Color> gradientForId(int id) {
    return placeholderGradients[id % placeholderGradients.length];
  }
}
