import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/usage_model.dart';
import '../services/payment_service.dart';
import '../services/usage_tracker.dart';
import 'app_providers.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});

final usageProvider = FutureProvider<UsageModel>((ref) async {
  final tracker   = ref.read(usageTrackerProvider);
  final payment   = ref.read(paymentServiceProvider);
  final isAnon    = await tracker.isAnonymous();
  final remaining = await tracker.queriesRemaining();
  final isPremium = payment.isPremium;
  // Registered (gratuito) users have limit=999 (unlimited + ads).
  // Anonymous users have a 10/day limit.
  final limit = isPremium ? 999 : isAnon ? UsageTracker.anonymousLimit : 999;
  final used  = isPremium ? 0   : isAnon ? limit - remaining : 0;
  return UsageModel(
    queriesUsed:  used,
    queriesLimit: limit,
    isPremium:    isPremium,
    isAnonymous:  isAnon,
  );
});

final canQueryProvider = FutureProvider<bool>((ref) async {
  final tracker = ref.read(usageTrackerProvider);
  return tracker.canQuery();
});
