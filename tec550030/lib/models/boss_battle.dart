/// This month's community boss and how close Hổ Flow is to beating it.
class BossBattle {
  final DateTime month;
  final String bossName;
  final int bossHp, tigerHp, todayHp, myHp, rewardPoints, daysLeft;
  final bool fightOpen, defeated, claimed;
  final List<BranchContribution> topBranches;

  const BossBattle({
    required this.month,
    required this.bossName,
    required this.bossHp,
    required this.tigerHp,
    this.todayHp = 0,
    required this.myHp,
    required this.rewardPoints,
    required this.daysLeft,
    required this.fightOpen,
    required this.defeated,
    required this.claimed,
    required this.topBranches,
  });

  double get progress => bossHp <= 0 ? 0 : (tigerHp / bossHp).clamp(0.0, 1.0);
  int get missingHp => (bossHp - tigerHp).clamp(0, bossHp);
  bool get strongEnough => tigerHp >= bossHp;

  factory BossBattle.fromJson(Map<String, dynamic> json) => BossBattle(
    month:
        DateTime.tryParse(json['month'] as String? ?? '') ??
        DateTime(DateTime.now().year, DateTime.now().month),
    bossName: json['boss_name'] as String? ?? 'Quái Vật Lười Biếng',
    bossHp: (json['boss_hp'] as num?)?.toInt() ?? 1,
    tigerHp: (json['tiger_hp'] as num?)?.toInt() ?? 0,
    todayHp: (json['today_hp'] as num?)?.toInt() ?? 0,
    myHp: (json['my_hp'] as num?)?.toInt() ?? 0,
    rewardPoints: (json['reward_points'] as num?)?.toInt() ?? 20,
    daysLeft: (json['days_left'] as num?)?.toInt() ?? 0,
    fightOpen: json['fight_open'] as bool? ?? false,
    defeated: json['defeated'] as bool? ?? false,
    claimed: json['claimed'] as bool? ?? false,
    topBranches: [
      for (final b in (json['top_branches'] as List? ?? []))
        BranchContribution.fromJson(Map<String, dynamic>.from(b as Map)),
    ],
  );
}

class BranchContribution {
  final String gymId, name;
  final int hp;
  const BranchContribution({
    required this.gymId,
    required this.name,
    required this.hp,
  });
  factory BranchContribution.fromJson(Map<String, dynamic> json) =>
      BranchContribution(
        gymId: json['gym_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        hp: (json['hp'] as num?)?.toInt() ?? 0,
      );
}

/// Result of pressing "Giao chiến".
enum BossFightResult { win, lose }
