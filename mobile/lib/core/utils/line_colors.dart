// mobile/lib/core/utils/line_colors.dart
import 'package:flutter/material.dart';

/// Static color map for all 16 São Paulo metro/CPTM lines.
/// Dark variants are always brighter than light for contrast on #121212 background.
class LineColors {
  LineColors._();

  static const List<String> allCodes = [
    'L1', 'L2', 'L3', 'L4', 'L5', 'L15',
    'L7', 'L8', 'L9', 'L10', 'L11', 'L12', 'L13', 'L17', 'LA', 'LB',
  ];

  static const Map<String, Color> _light = {
    'L1':  Color(0xFF0455A1), // Azul
    'L2':  Color(0xFF007E5E), // Verde
    'L3':  Color(0xFFEF4136), // Vermelha
    'L4':  Color(0xFFFFD900), // Amarela
    'L5':  Color(0xFF9B2990), // Lilás
    'L15': Color(0xFF808285), // Prata
    'L7':  Color(0xFFCF202E), // Rubi
    'L8':  Color(0xFF97999B), // Diamante
    'L9':  Color(0xFF00945A), // Esmeralda
    'L10': Color(0xFF007A87), // Turquesa
    'L11': Color(0xFFF26522), // Coral
    'L12': Color(0xFF133A8F), // Safira
    'L13': Color(0xFF00A859), // Jade
    'L17': Color(0xFFBE9B2F), // Ouro
    'LA':  Color(0xFF6B3A2A), // Santos-Jundiaí
    'LB':  Color(0xFF005A8B), // Diamante Expresso
  };

  static const Map<String, Color> _dark = {
    'L1':  Color(0xFF2979FF), // Azul — brighter
    'L2':  Color(0xFF00BFA5), // Verde — brighter
    'L3':  Color(0xFFFF5252), // Vermelha — brighter
    'L4':  Color(0xFFFFE57F), // Amarela — brighter
    'L5':  Color(0xFFCE93D8), // Lilás — brighter
    'L15': Color(0xFFB0BEC5), // Prata — brighter
    'L7':  Color(0xFFEF5350), // Rubi — brighter
    'L8':  Color(0xFFCFD8DC), // Diamante — brighter
    'L9':  Color(0xFF69F0AE), // Esmeralda — brighter
    'L10': Color(0xFF80DEEA), // Turquesa — brighter
    'L11': Color(0xFFFF9E80), // Coral — brighter
    'L12': Color(0xFF448AFF), // Safira — brighter
    'L13': Color(0xFFB9F6CA), // Jade — brighter
    'L17': Color(0xFFFFD740), // Ouro — brighter
    'LA':  Color(0xFFA1887F), // Santos-Jundiaí — brighter
    'LB':  Color(0xFF4FC3F7), // Diamante Expresso — brighter
  };

  /// Returns the appropriate color for [code] based on [brightness].
  /// Returns [Colors.grey] for unknown codes.
  static Color forLine(String code, Brightness brightness) {
    final map = brightness == Brightness.dark ? _dark : _light;
    return map[code] ?? Colors.grey;
  }
}
