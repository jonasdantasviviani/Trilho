import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../constants.dart';

/// State entry for a single station from SignalR.
class SignalRCrowdEntry {
  final String densityLevel;
  final double density;
  final DateTime updatedAt;

  const SignalRCrowdEntry({
    required this.densityLevel,
    required this.density,
    required this.updatedAt,
  });
}

class SignalRNotifier extends StateNotifier<Map<int, SignalRCrowdEntry>> {
  late final HubConnection _hub;

  SignalRNotifier() : super({}) {
    _connect();
  }

  Future<void> _connect() async {
    _hub = HubConnectionBuilder()
        .withUrl(AppConstants.signalrHubUrl)
        .withAutomaticReconnect()
        .build();

    _hub.on('CrowdUpdated', (args) {
      if (args == null || args.isEmpty) return;
      final data       = args[0] as Map<String, dynamic>;
      final stationId  = data['stationId'] as int;
      final level      = data['densityLevel'] as String;
      final density    = (data['density'] as num?)?.toDouble() ?? _densityFromLevel(level);
      state = {
        ...state,
        stationId: SignalRCrowdEntry(
          densityLevel: level,
          density: density,
          updatedAt: DateTime.now(),
        ),
      };
    });

    try {
      await _hub.start();
    } catch (e) {
      debugPrint('SignalR connection failed: $e');
    }
  }

  Future<void> subscribeLine(String lineCode) async {
    if (_hub.state == HubConnectionState.Connected) {
      await _hub.invoke('SubscribeLine', args: [lineCode]);
    }
  }

  /// Fallback density values when the backend doesn't send a float.
  static double _densityFromLevel(String level) => switch (level) {
        'Low'    => 0.25,
        'Medium' => 0.50,
        'High'   => 0.75,
        'Packed' => 0.95,
        _        => 0.5,
      };

  @override
  void dispose() {
    _hub.stop();
    super.dispose();
  }
}

final signalRProvider =
    StateNotifierProvider<SignalRNotifier, Map<int, SignalRCrowdEntry>>(
  (ref) => SignalRNotifier(),
);
