class UsageModel {
  final int queriesUsed;
  final int queriesLimit;
  final bool isPremium;
  final bool isAnonymous;

  const UsageModel({
    required this.queriesUsed,
    required this.queriesLimit,
    required this.isPremium,
    required this.isAnonymous,
  });

  factory UsageModel.fromJson(Map<String, dynamic> j) => UsageModel(
        queriesUsed: j['queriesUsed'] as int,
        queriesLimit: j['queriesLimit'] as int,
        isPremium: j['isPremium'] as bool,
        isAnonymous: j['isAnonymous'] as bool? ?? true,
      );

  bool get canQuery => isPremium || queriesUsed < queriesLimit;
  int get remaining => isPremium ? 999 : (queriesLimit - queriesUsed).clamp(0, queriesLimit);
}
