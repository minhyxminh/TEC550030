class GymPointBalance {
  final int balance;

  GymPointBalance({required this.balance});

  factory GymPointBalance.fromJson(Map<String, dynamic> json) {
    return GymPointBalance(balance: json['balance'] ?? 0);
  }
}
