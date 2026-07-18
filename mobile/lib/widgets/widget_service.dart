import 'package:home_widget/home_widget.dart';
import 'package:flutter/material.dart';

class WidgetService {
  static const String _appGroupId = 'group.com.trilho.trilho';
  static const String _androidWidgetName = 'TrilhoStatusWidget';
  static const String _iOSWidgetName = 'TrilhoWidget';

  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  static Future<void> updateWidget({
    required String lineName,
    required String status,
    required String statusColor,
    required String crowdLevel,
    required String lastUpdated,
  }) async {
    await HomeWidget.saveWidgetData('lineName', lineName);
    await HomeWidget.saveWidgetData('status', status);
    await HomeWidget.saveWidgetData('statusColor', statusColor);
    await HomeWidget.saveWidgetData('crowdLevel', crowdLevel);
    await HomeWidget.saveWidgetData('lastUpdated', lastUpdated);

    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
      iOSName: _iOSWidgetName,
    );
  }

  static Future<void> clearWidget() async {
    await HomeWidget.saveWidgetData('lineName', 'Trilho');
    await HomeWidget.saveWidgetData('status', 'Carregando...');
    await HomeWidget.saveWidgetData('statusColor', '#9E9E9E');
    await HomeWidget.saveWidgetData('crowdLevel', '-');
    await HomeWidget.saveWidgetData('lastUpdated', '');

    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
      iOSName: _iOSWidgetName,
    );
  }
}

class TrilhoWidgetData {
  final String lineName;
  final String status;
  final String statusColor;
  final String crowdLevel;
  final DateTime lastUpdated;

  TrilhoWidgetData({
    required this.lineName,
    required this.status,
    required this.statusColor,
    required this.crowdLevel,
    required this.lastUpdated,
  });

  Color get statusColorParsed {
    final hex = statusColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  Color get crowdLevelColor {
    switch (crowdLevel.toLowerCase()) {
      case 'low':
      case 'baixa':
        return Colors.green;
      case 'medium':
      case 'média':
      case 'media':
        return Colors.orange;
      case 'high':
      case 'alta':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get formattedTime {
    final diff = DateTime.now().difference(lastUpdated);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
