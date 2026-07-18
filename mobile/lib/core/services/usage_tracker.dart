import 'package:hive_flutter/hive_flutter.dart';
import 'payment_service.dart';

class UsageTracker {
  static const _usageBox = 'usage';
  static const _prefsBox = 'app_prefs';

  // Anonymous users: 10 queries/day (resets daily). Registered users: unlimited + ads.
  static const int anonymousLimit = 10;

  static final PaymentService _payment = PaymentService();

  Future<bool> _isSocialAuth() async {
    final box = Hive.box(_prefsBox);
    return box.get('is_social_auth') == 'true';
  }

  Future<bool> canQuery() async {
    if (_payment.isPremium) return true;
    final isSocial = await _isSocialAuth();
    if (isSocial) return true; // registered users: unlimited basic access + ads
    final box = await Hive.openBox<dynamic>(_usageBox);
    _resetIfNewDay(box);
    final count = box.get('count', defaultValue: 0) as int;
    return count < anonymousLimit;
  }

  Future<void> recordQuery() async {
    if (_payment.isPremium) return;
    final box = await Hive.openBox<dynamic>(_usageBox);
    _resetIfNewDay(box);
    final count = box.get('count', defaultValue: 0) as int;
    await box.put('count', count + 1);
  }

  Future<int> queriesRemaining() async {
    if (_payment.isPremium) return 999;
    final isSocial = await _isSocialAuth();
    if (isSocial) return 999;
    final box = await Hive.openBox<dynamic>(_usageBox);
    _resetIfNewDay(box);
    final count = box.get('count', defaultValue: 0) as int;
    return (anonymousLimit - count).clamp(0, anonymousLimit);
  }

  Future<bool> isAnonymous() => _isSocialAuth().then((v) => !v);

  // ── Crowdsourcing contribution tracking ─────────────────────────────────────

  /// Records a background geofence ping contribution for today.
  Future<void> recordPing() async {
    final box = await Hive.openBox<dynamic>(_usageBox);
    _resetPingsIfNewDay(box);
    final count = box.get('pings_count', defaultValue: 0) as int;
    await box.put('pings_count', count + 1);
  }

  /// Returns how many station pings this user made today.
  Future<int> pingsTodayCount() async {
    final box = await Hive.openBox<dynamic>(_usageBox);
    _resetPingsIfNewDay(box);
    return box.get('pings_count', defaultValue: 0) as int;
  }

  void _resetIfNewDay(Box<dynamic> box) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (box.get('date') != today) {
      box.put('date', today);
      box.put('count', 0);
    }
  }

  void _resetPingsIfNewDay(Box<dynamic> box) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (box.get('pings_date') != today) {
      box.put('pings_date', today);
      box.put('pings_count', 0);
    }
  }
}
